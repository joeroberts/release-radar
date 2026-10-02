import tempfile
import unittest
from pathlib import Path

from policy import Policy, PolicyError, worker_overrides, validate_history_profile, validate_launcher_protection


class PolicyTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.checkout = self.root / 'checkout'
        self.checkout.mkdir()
        self.config = {'executable': '/bin/echo', 'assignments': {
            'review': {'cwd': str(self.checkout), 'permissions': 'project-ro',
                       'models': {'gpt-5.6-terra': ['medium', 'high']},
                       'excludedPaths': [str(self.checkout / 'history')]}}}

    def test_assignment_resolves_only_allowlisted_settings(self):
        p = Policy(self.config)
        selected = p.select('review', 'gpt-5.6-terra', 'high')
        self.assertEqual(selected['cwd'], str(self.checkout))
        self.assertEqual(selected['permissions'], 'project-ro')

    def test_reject_unknown_assignment_model_effort_and_full_access(self):
        p = Policy(self.config)
        for args in [('other', 'gpt-5.6-terra', 'high'),
                     ('review', 'other', 'high'),
                     ('review', 'gpt-5.6-terra', 'ultra')]:
            with self.assertRaises(PolicyError): p.select(*args)
        self.config['assignments']['review']['permissions'] = ':danger-full-access'
        with self.assertRaises(PolicyError): Policy(self.config)

    def test_reject_symlink_checkout_instead_of_silently_resolving(self):
        alias = self.root / 'alias'
        alias.symlink_to(self.checkout)
        self.config['assignments']['review']['cwd'] = str(alias)
        with self.assertRaises(PolicyError): Policy(self.config)

    def test_disable_each_configured_retrieval_service(self):
        c = worker_overrides({'mcp_servers': {'launcher': {}, 'search': {}},
                              'plugins': {'thing@market': {'enabled': True}}})
        self.assertFalse(c['mcp_servers.launcher.enabled'])
        self.assertFalse(c['mcp_servers.search.enabled'])
        self.assertFalse(c['plugins.thing@market.enabled'])
        self.assertFalse(c['features.apps'])
        self.assertFalse(c['features.multi_agent'])
        self.assertFalse(c['agents.enabled'])
        self.assertNotIn('features.code_mode_host', c)
        self.assertEqual(c['web_search'], 'disabled')

    def test_history_denial_rejects_narrower_grant(self):
        selected = Policy(self.config).select('review', 'gpt-5.6-terra', 'high')
        fs = {':root': 'deny', ':workspace_roots': {'.': 'read', '.git': 'deny', 'history': 'deny'}}
        profile = {'filesystem': fs, 'network': {'enabled': False}}
        config = {'permissions': {'project-ro': profile}}
        validate_history_profile(config, selected)
        fs[':workspace_roots']['history/secret'] = 'read'
        with self.assertRaises(PolicyError): validate_history_profile(config, selected)
        del fs[':workspace_roots']['history/secret']

    def test_network_is_tightened_per_session(self):
        c = worker_overrides({}, 'project-restricted')
        self.assertFalse(c['permissions.project-restricted.network.enabled'])

    def test_executable_in_worker_checkout_is_rejected(self):
        executable = self.checkout / 'codex'
        executable.write_text('#!/bin/sh\n')
        executable.chmod(0o700)
        self.config['executable'] = str(executable)
        with self.assertRaises(PolicyError): Policy(self.config)

    def test_launcher_protection_checks_outside_root_grants_and_parents(self):
        selected = Policy(self.config).select('review', 'gpt-5.6-terra', 'high')
        protected = self.root / 'launcher' / 'server.py'
        fs = {':root': 'deny', ':minimal': 'read', ':workspace_roots': {'.': 'write'}}
        config = {'permissions': {'project-ro': {'filesystem': fs}}}
        validate_launcher_protection(config, selected, [protected])
        for target in [protected, protected.parent, self.root]:
            fs[str(target)] = 'write'
            with self.assertRaises(PolicyError):
                validate_launcher_protection(config, selected, [protected])
            del fs[str(target)]
        fs[':unknown-special-root'] = 'write'
        with self.assertRaises(PolicyError):
            validate_launcher_protection(config, selected, [protected])

    def test_linked_worktree_requires_common_git_denial(self):
        common = self.root / 'repository' / '.git'
        metadata = common / 'worktrees' / 'assigned'
        metadata.mkdir(parents=True)
        (metadata / 'commondir').write_text('../..\n')
        (self.checkout / '.git').write_text('gitdir: ' + str(metadata) + '\n')
        selected = Policy(self.config).select('review', 'gpt-5.6-terra', 'high')
        fs = {':root': 'deny', ':workspace_roots': {
            '.': 'read', '.git': 'deny', 'history': 'deny'}}
        config = {'permissions': {'project-ro': {'filesystem': fs}}}
        with self.assertRaisesRegex(PolicyError, 'explicit history denial'):
            validate_history_profile(config, selected)
        fs[str(common)] = 'deny'
        validate_history_profile(config, selected)
        fs[str(common / 'objects')] = 'read'
        with self.assertRaisesRegex(PolicyError, 'Narrower grant'):
            validate_history_profile(config, selected)


if __name__ == '__main__': unittest.main()
