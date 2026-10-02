"""Owner-configured assignment limits. Tool callers cannot supply config overrides."""

from pathlib import Path
import os
import sys
import tempfile


class PolicyError(ValueError):
    pass


def exact_directory(value):
    if not isinstance(value, str) or not Path(value).is_absolute():
        raise PolicyError('Checkout must be an absolute directory')
    path = Path(value)
    if not path.is_dir() or str(path.resolve()) != value:
        raise PolicyError('Checkout must exist and be canonical, with no symlink aliases')
    return value


class Policy:
    def __init__(self, document):
        if set(document) != {'executable', 'assignments'}:
            raise PolicyError('Policy requires only executable and assignments')
        self.executable = document['executable']
        if not isinstance(self.executable, str) or not Path(self.executable).is_absolute():
            raise PolicyError('Executable must be an explicit absolute path')
        executable = Path(self.executable)
        if (str(executable.resolve()) != self.executable or not executable.is_file()
                or not os.access(executable, os.X_OK)):
            raise PolicyError('Executable must be an existing canonical executable file')
        self.protected_paths = [executable, Path(__file__).resolve().parent,
                                Path(sys.executable).resolve()]
        self.assignments = document['assignments']
        if not isinstance(self.assignments, dict) or not self.assignments:
            raise PolicyError('At least one owner-configured assignment is required')
        for name, entry in self.assignments.items():
            if not isinstance(name, str) or not name or not isinstance(entry, dict):
                raise PolicyError('Invalid assignment')
            if set(entry) != {'cwd', 'permissions', 'models', 'excludedPaths'}:
                raise PolicyError('Assignment requires cwd, permissions, models and excludedPaths only')
            exact_directory(entry['cwd'])
            if Path(entry['cwd']) in executable.parents:
                raise PolicyError('App Server executable must be outside worker checkouts')
            excluded = entry['excludedPaths']
            if (not isinstance(excluded, list) or not excluded or
                any(not isinstance(p, str) or not Path(p).is_absolute() for p in excluded)):
                raise PolicyError('Provide explicit absolute historical and shared-Git exclusion paths')
            profile = entry['permissions']
            if not isinstance(profile, str) or not profile or profile.startswith(':'):
                raise PolicyError('Assignment requires an explicit named permission profile')
            models = entry['models']
            if not isinstance(models, dict) or not models:
                raise PolicyError('Assignment requires allowed models and efforts')
            for model, efforts in models.items():
                if (not isinstance(model, str) or not model or
                    not isinstance(efforts, list) or not efforts or
                    any(e not in ('low', 'medium', 'high', 'xhigh', 'max') for e in efforts)):
                    raise PolicyError('Invalid model or effort allowlist; Ultra is prohibited')

    def select(self, assignment, model, effort):
        entry = self.assignments.get(assignment)
        if entry is None or effort not in entry['models'].get(model, []):
            raise PolicyError('Assignment/model/effort is not owner-allowed')
        exact_directory(entry['cwd'])
        return {'cwd': entry['cwd'], 'permissions': entry['permissions'],
                'model': model, 'effort': effort, 'excludedPaths': entry['excludedPaths']}


def validate_history_profile(config, selected):
    """Validate an intentionally narrow supported profile shape, not a policy simulator.

    Profiles with inheritance/globs/extra roots require owner simplification rather
    than guessing about effective precedence. No profile or user file is changed.
    """
    profile = config.get('permissions', {}).get(selected['permissions'])
    if not isinstance(profile, dict) or profile.get('extends'):
        raise PolicyError('History exclusion requires a concrete, non-inherited named profile')
    fs = profile.get('filesystem', {})
    if fs.get(':root') != 'deny':
        raise PolicyError('History-excluded workers require root deny')
    if profile.get('workspace_roots'):
        raise PolicyError('Additional profile workspace roots are outside this assignment')
    # Absolute exclusions must be present. Workspace-relative duplicates remain valid.
    rules = {}
    for path, access in fs.items():
        if path.startswith(':') or path == 'glob_scan_max_depth':
            continue
        if any(c in path for c in '*?['):
            raise PolicyError('Glob filesystem rules are not supported for history-excluded assignments')
        rules[str(Path(path).expanduser().resolve())] = access
    relative = fs.get(':workspace_roots', {})
    if not isinstance(relative, dict):
        raise PolicyError('Expected workspace-relative filesystem rules')
    for path, access in relative.items():
        if any(c in path for c in '*?['):
            raise PolicyError('Glob workspace rules are not supported')
        rules[str((Path(selected['cwd']) / path).resolve())] = access
    exclusions = list(selected['excludedPaths'])
    git_entry = Path(selected['cwd']) / '.git'
    if git_entry.is_file():
        pointer = git_entry.read_text().strip()
        if not pointer.startswith('gitdir: '):
            raise PolicyError('Unrecognized worktree Git pointer')
        metadata = (git_entry.parent / pointer[8:]).resolve()
        common_file = metadata / 'commondir'
        common = (metadata / common_file.read_text().strip()).resolve() if common_file.is_file() else metadata
        # A deny on the common Git directory covers its worktree metadata too.
        exclusions.append(str(common))
    for excluded in exclusions:
        target = Path(excluded).resolve()
        if rules.get(str(target)) != 'deny':
            raise PolicyError('Profile lacks explicit history denial: ' + str(target))
        for path, access in rules.items():
            if access != 'deny' and target in Path(path).parents:
                raise PolicyError('Narrower grant reopens excluded history: ' + path)
    if rules.get(str((Path(selected['cwd']) / '.git').resolve())) != 'deny':
        raise PolicyError('Profile must deny checkout .git')


def validate_launcher_protection(config, selected, protected_paths):
    """Reject write grants overlapping launcher files or replaceable ancestors.

    Conservative: a narrower deny does not excuse a writable ancestor. Unknown
    special write roots are rejected rather than approximating runtime policy.
    """
    fs = config['permissions'][selected['permissions']]['filesystem']
    protected = [Path(p).resolve() for p in protected_paths]
    writes = []
    for key, access in fs.items():
        if key == ':workspace_roots':
            writes.extend((Path(selected['cwd']) / p).resolve()
                          for p, a in access.items() if a == 'write')
        elif access == 'write':
            if key == ':tmpdir':
                writes.extend(Path(p).resolve() for p in
                              (tempfile.gettempdir(), '/tmp', '/private/tmp'))
            elif key.startswith(':'):
                raise PolicyError('Unsupported special write root: ' + key)
            else:
                writes.append(Path(key).expanduser().resolve())
    for writable in writes:
        for target in protected:
            if writable == target or writable in target.parents or target in writable.parents:
                raise PolicyError('Worker write grant overlaps launcher or its parent: ' + str(writable))


def worker_overrides(effective_config, permission_profile=None):
    """Fixed tightening only. Disabled service inventory comes from config/read."""
    result = {
        'features.apps': False,
        'features.plugins': False,
        'features.browser_use': False,
        'features.browser_use_external': False,
        'features.browser_use_full_cdp_access': False,
        'features.computer_use': False,
        'features.in_app_browser': False,
        'features.multi_agent': False,
        'features.multi_agent_v2': False,
        'agents.enabled': False,
        'features.memories': False,
        'features.remote_plugin': False,
        'features.skill_mcp_dependency_install': False,
        'features.image_generation': False,
        'features.view_image': False,
        'tools.view_image': False,
        'web_search': 'disabled',
    }
    if permission_profile is not None:
        if '.' in permission_profile or '"' in permission_profile:
            raise PolicyError('Unsupported dotted/quoted permission-profile name')
        # Session-local tightening; preserve the installed profile on disk.
        result['permissions.' + permission_profile + '.network.enabled'] = False
    for section in ('mcp_servers', 'plugins'):
        entries = effective_config.get(section, {}) or {}
        if not isinstance(entries, dict):
            raise PolicyError('Cannot determine configured ' + section)
        for name in entries:
            if '.' in name or '"' in name:
                raise PolicyError('Unsupported dotted/quoted service name; cannot safely override: ' + name)
            result[section + '.' + name + '.enabled'] = False
    return result
