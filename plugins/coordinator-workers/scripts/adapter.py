"""Bounded worker lifecycle over App Server; no desktop session attachment."""

import asyncio
import json
import uuid

from policy import PolicyError, worker_overrides, validate_history_profile, validate_launcher_protection
from transport import AppServer, TransportLost


class Adapter:
    def __init__(self, policy, server_factory=AppServer.open):
        self.policy = policy
        self.server_factory = server_factory
        self.workers = {}
        self.start_lock = asyncio.Lock()

    def _worker(self, worker_id):
        if worker_id not in self.workers:
            raise PolicyError('Unknown worker; only workers created by this connection are accessible')
        return self.workers[worker_id]

    @staticmethod
    def _prompt(prompt):
        if not isinstance(prompt, str) or not prompt.strip() or len(prompt) > 64000:
            raise PolicyError('Assignment must contain 1–64000 characters')

    def _event(self, worker, message):
        method, params = message['method'], message.get('params', {})
        if method == 'adapter/connectionLost':
            worker['status'] = 'unknown'
            worker['connectionLost'] = True
            return
        if 'id' in message:
            # Opaque IDs retain JSON type; respond only to a pending exact request.
            key = str(uuid.uuid4())
            worker['approvals'][key] = message
            worker['status'] = 'awaitingApproval'
            return
        if params.get('threadId') != worker.get('threadId'):
            return
        if method == 'turn/started':
            worker['turnId'] = params['turn']['id']
            worker['status'] = 'running'
        elif method == 'turn/completed':
            turn = params['turn']
            worker['turnId'] = turn['id']
            worker['status'] = turn.get('status', 'unknown')
            worker['error'] = turn.get('error')
            worker['approvals'].clear()
        elif method == 'serverRequest/resolved':
            rid = params.get('requestId')
            for key, request in list(worker['approvals'].items()):
                if request['id'] == rid:
                    del worker['approvals'][key]
        elif method == 'item/completed':
            item = params.get('item', {})
            if item.get('type') == 'agentMessage':
                text = item.get('text', '')
                if len(text) > 32000 or len(worker['messages']) >= 20:
                    worker['messagesTruncated'] = True
                worker['messages'].append(text[:32000])
                worker['messages'] = worker['messages'][-20:]

    async def start(self, assignment, model, effort, prompt):
        self._prompt(prompt)
        selected = self.policy.select(assignment, model, effort)
        async with self.start_lock:
            if len(self.workers) >= 8:
                raise PolicyError('Connection limit reached; close a finished worker first')
            worker_id = str(uuid.uuid4())
            worker = {'workerId': worker_id, 'status': 'starting', 'messages': [],
                      'approvals': {}, 'selected': selected, 'lock': asyncio.Lock()}
            self.workers[worker_id] = worker
            try:
                argv = [self.policy.executable, 'app-server', '--listen', 'stdio://']
                for key, value in worker_overrides({}, selected['permissions']).items():
                    argv.extend(['-c', key + '=' + json.dumps(value)])
                server = await self.server_factory(
                    argv,
                    lambda m: self._event(worker, m))
                worker['server'] = server
                await server.call('initialize', {
                    'clientInfo': {'name': 'coordinator_workers', 'version': '0.1.0'},
                    'capabilities': {'experimentalApi': True}})
                await server.send({'method': 'initialized'})
                config = (await server.call('config/read', {
                    'cwd': selected['cwd'], 'includeLayers': False}))['config']
                validate_history_profile(config, selected)
                validate_launcher_protection(config, selected, self.policy.protected_paths)
                overrides = worker_overrides(config, selected['permissions'])
                overrides['model_reasoning_effort'] = effort
                result = await server.call('thread/start', {
                    'cwd': selected['cwd'], 'runtimeWorkspaceRoots': [selected['cwd']],
                    'permissions': selected['permissions'], 'model': model,
                    'allowProviderModelFallback': False, 'config': overrides})
                worker['threadId'] = result['thread']['id']
                worker['effective'] = {k: result.get(k) for k in (
                    'cwd', 'runtimeWorkspaceRoots', 'model', 'reasoningEffort',
                    'activePermissionProfile', 'sandbox', 'approvalPolicy',
                    'approvalsReviewer', 'instructionSources')}
                effective = worker['effective']
                profile = effective.get('activePermissionProfile') or {}
                if (effective['cwd'] != selected['cwd'] or
                    effective['model'] != model or profile.get('id') != selected['permissions'] or
                    effective['reasoningEffort'] != effort or
                    effective['runtimeWorkspaceRoots'] != [selected['cwd']] or
                    (effective.get('sandbox') or {}).get('networkAccess') is not False):
                    raise PolicyError('App Server settings did not match assignment; no turn started')
                cursor = None
                while True:
                    inventory = await server.call('mcpServerStatus/list', {
                        'threadId': worker['threadId'], 'detail': 'full',
                        'cursor': cursor, 'limit': 100})
                    if any(s.get('tools') or s.get('resources') or s.get('resourceTemplates')
                           for s in inventory.get('data', [])):
                        raise PolicyError('Worker still exposes MCP retrieval tools; no turn started')
                    cursor = inventory.get('nextCursor')
                    if not cursor: break
                worker['status'] = 'ready'
                worker['verified'] = True
                await self.follow_up(worker_id, prompt)
            except Exception as exc:
                worker['status'] = 'unknown' if isinstance(exc, TransportLost) else 'failed'
                worker['error'] = str(exc)
                # Preserve identity on partial launch; no automatic retry or silent replacement.
            return self.status(worker_id)

    def status(self, worker_id):
        worker = self._worker(worker_id)
        result = {k: v for k, v in worker.items()
                  if k not in ('server', 'lock', 'approvals')}
        result['pendingRequests'] = [
            {'requestKey': key, 'method': value['method'], 'params': value.get('params', {})}
            for key, value in worker['approvals'].items()]
        return result

    async def follow_up(self, worker_id, prompt):
        self._prompt(prompt)
        worker = self._worker(worker_id)
        async with worker['lock']:
            if (not worker.get('verified') or worker['status'] not in
                ('ready', 'completed', 'interrupted', 'failed') or 'threadId' not in worker):
                raise PolicyError('Worker cannot start another turn in current state')
            worker['status'] = 'startingTurn'
            worker['messages'] = []
            worker['messagesTruncated'] = False
            try:
                result = await worker['server'].call('turn/start', {
                    'threadId': worker['threadId'],
                    'effort': worker['selected']['effort'],
                    'input': [{'type': 'text', 'text': prompt, 'text_elements': []}]})
                worker['turnId'] = result['turn']['id']
                if worker['status'] == 'startingTurn':
                    worker['status'] = result['turn'].get('status', 'inProgress')
            except TransportLost:
                worker['status'] = 'unknown'
                raise
            except Exception:
                worker['status'] = 'failed'
                raise
        return self.status(worker_id)

    async def interrupt(self, worker_id):
        worker = self._worker(worker_id)
        if not worker.get('turnId') or worker['status'] in ('unknown', 'closed'):
            raise PolicyError('No known connected turn to interrupt')
        await worker['server'].call('turn/interrupt', {
            'threadId': worker['threadId'], 'turnId': worker['turnId']})
        # Only turn/completed can establish interruption; the response is an acknowledgement.
        return self.status(worker_id)

    async def respond(self, worker_id, request_key, decision):
        worker = self._worker(worker_id)
        async with worker['lock']:
            request = worker['approvals'].get(request_key)
            if request is None:
                raise PolicyError('Approval is absent, stale or already answered')
            params = request.get('params', {})
            if (params.get('threadId') != worker.get('threadId') or
                params.get('turnId') != worker.get('turnId')):
                raise PolicyError('Approval does not belong to the current worker turn')
            if request['method'] not in ('item/commandExecution/requestApproval',
                                         'item/fileChange/requestApproval'):
                raise PolicyError('Unsupported request type; surfaced without granting authority')
            if decision not in ('accept', 'decline', 'cancel'):
                raise PolicyError('Only one-action accept, decline or cancel is supported')
            allowed = params.get('availableDecisions')
            if allowed is not None and decision not in allowed:
                raise PolicyError('Decision is not offered by App Server')
            worker['approvals'].pop(request_key, None)
            try:
                await worker['server'].send({'id': request['id'], 'result': {'decision': decision}})
            except TransportLost:
                worker['status'] = 'unknown'
                worker['uncertainApproval'] = {'requestKey': request_key, 'decision': decision}
                raise
            if worker['status'] == 'awaitingApproval':
                worker['status'] = 'awaitingApproval' if worker['approvals'] else 'running'
        return self.status(worker_id)

    async def close(self, worker_id):
        worker = self._worker(worker_id)
        if worker['status'] not in ('completed', 'interrupted', 'failed', 'ready'):
            raise PolicyError('Interrupt active work and observe completion before closing')
        if worker.get('server'):
            await worker['server'].close()
        del self.workers[worker_id]
        return {'workerId': worker_id, 'status': 'connectionClosed',
                'threadId': worker.get('threadId')}
