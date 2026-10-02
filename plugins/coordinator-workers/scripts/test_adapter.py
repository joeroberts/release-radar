import unittest

from adapter import Adapter
from policy import PolicyError
from transport import TransportLost


class Assignment:
    executable = '/explicit/codex'
    protected_paths = ['/explicit/codex', '/launcher/server.py']
    def select(self, assignment, model, effort):
        return {'cwd': '/assigned', 'permissions': 'worker-ro',
                'model': model, 'effort': effort, 'excludedPaths': ['/assigned/history']}


class Peer:
    def __init__(self, argv, callback):
        self.argv, self.callback, self.calls, self.sent = argv, callback, [], []
        self.mismatch = False
        self.tools = False
        self.lost = False

    async def send(self, message): self.sent.append(message)
    async def close(self): pass
    async def call(self, method, params):
        self.calls.append((method, params))
        if method == 'config/read': return {'config': {
            'mcp_servers': {'launcher': {}}, 'permissions': {'worker-ro': {
                'filesystem': {':root': 'deny', ':workspace_roots': {
                    '.': 'read', '.git': 'deny', 'history': 'deny'}},
                'network': {'enabled': False}}}}}
        if method == 'thread/start':
            return {'thread': {'id': 'thread-1'}, 'cwd': '/assigned',
                    'model': params['model'], 'reasoningEffort': 'high',
                    'sandbox': {'networkAccess': False},
                    'runtimeWorkspaceRoots': ['/assigned'],
                    'activePermissionProfile': {'id': 'wrong' if self.mismatch else 'worker-ro'}}
        if method == 'mcpServerStatus/list':
            return {'data': [{'tools': {'launcher': {}}}] if self.tools else [], 'nextCursor': None}
        if method == 'turn/start':
            if self.lost: raise TransportLost('uncertain turn')
            return {'turn': {'id': 'turn-1', 'status': 'inProgress'}}
        return {}


class AdapterTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.peers = []
        self.mismatch = self.tools = self.lost = False
        async def factory(argv, callback):
            peer = Peer(argv, callback)
            peer.mismatch, peer.tools, peer.lost = self.mismatch, self.tools, self.lost
            self.peers.append(peer)
            return peer
        self.adapter = Adapter(Assignment(), factory)

    async def start(self):
        return await self.adapter.start('review', 'gpt-5.6-terra', 'high', 'Review assigned files')

    async def test_explicit_start_and_followup_keep_configuration(self):
        status = await self.start()
        peer = self.peers[0]
        self.assertIn('features.multi_agent=false', peer.argv)
        self.assertIn('features.plugins=false', peer.argv)
        params = next(p for m,p in peer.calls if m == 'thread/start')
        self.assertEqual(params['permissions'], 'worker-ro')
        self.assertEqual(params['runtimeWorkspaceRoots'], ['/assigned'])
        self.assertFalse(params['config']['mcp_servers.launcher.enabled'])
        peer.callback({'method': 'turn/completed', 'params': {
            'threadId': 'thread-1', 'turn': {'id': 'turn-1', 'status': 'completed'}}})
        await self.adapter.follow_up(status['workerId'], 'Make the required correction')
        self.assertEqual(len([m for m,p in peer.calls if m == 'thread/start']), 1)

    async def test_settings_mismatch_never_releases_turn_even_via_followup(self):
        self.mismatch = True
        status = await self.start()
        self.assertEqual(status['status'], 'failed')
        self.assertNotIn('turn/start', [m for m,p in self.peers[0].calls])
        with self.assertRaises(PolicyError):
            await self.adapter.follow_up(status['workerId'], 'Try again')

    async def test_retrieval_tool_presence_blocks_turn(self):
        self.tools = True
        status = await self.start()
        self.assertEqual(status['status'], 'failed')
        self.assertNotIn('turn/start', [m for m,p in self.peers[0].calls])

    async def test_uncertain_turn_not_retried(self):
        self.lost = True
        status = await self.start()
        self.assertEqual(status['status'], 'unknown')
        with self.assertRaises(PolicyError):
            await self.adapter.follow_up(status['workerId'], 'Try again')
        self.assertEqual(len([m for m,p in self.peers[0].calls if m == 'turn/start']), 1)

    async def test_approval_identity_and_replay(self):
        status = await self.start()
        peer = self.peers[0]
        peer.callback({'id': 78, 'method': 'item/fileChange/requestApproval',
                       'params': {'threadId': 'thread-1', 'turnId': 'turn-1'}})
        request = self.adapter.status(status['workerId'])['pendingRequests'][0]['requestKey']
        with self.assertRaises(PolicyError):
            await self.adapter.respond(status['workerId'], request, 'acceptForSession')
        await self.adapter.respond(status['workerId'], request, 'decline')
        self.assertEqual(peer.sent[-1], {'id': 78, 'result': {'decision': 'decline'}})
        with self.assertRaises(PolicyError):
            await self.adapter.respond(status['workerId'], request, 'accept')

    async def test_interrupt_ack_is_not_completion(self):
        status = await self.start()
        result = await self.adapter.interrupt(status['workerId'])
        self.assertEqual(result['status'], 'inProgress')
        with self.assertRaises(PolicyError): await self.adapter.close(status['workerId'])

    async def test_completion_during_approval_response_remains_terminal(self):
        status = await self.start()
        peer = self.peers[0]
        peer.callback({'id': 78, 'method': 'item/fileChange/requestApproval',
                       'params': {'threadId': 'thread-1', 'turnId': 'turn-1'}})
        key = self.adapter.status(status['workerId'])['pendingRequests'][0]['requestKey']
        async def send(message):
            peer.callback({'method': 'turn/completed', 'params': {
                'threadId': 'thread-1', 'turn': {'id': 'turn-1', 'status': 'completed'}}})
        peer.send = send
        result = await self.adapter.respond(status['workerId'], key, 'decline')
        self.assertEqual(result['status'], 'completed')

    async def test_result_truncation_is_explicit(self):
        status = await self.start()
        self.peers[0].callback({'method': 'item/completed', 'params': {
            'threadId': 'thread-1', 'item': {'type': 'agentMessage', 'text': 'x' * 32001}}})
        result = self.adapter.status(status['workerId'])
        self.assertTrue(result['messagesTruncated'])

    async def test_uncertain_approval_cannot_be_replayed(self):
        status = await self.start()
        peer = self.peers[0]
        peer.callback({'id': 78, 'method': 'item/fileChange/requestApproval',
                       'params': {'threadId': 'thread-1', 'turnId': 'turn-1'}})
        key = self.adapter.status(status['workerId'])['pendingRequests'][0]['requestKey']
        async def lost(message): raise TransportLost('delivery uncertain')
        peer.send = lost
        with self.assertRaises(TransportLost):
            await self.adapter.respond(status['workerId'], key, 'accept')
        self.assertEqual(self.adapter.status(status['workerId'])['status'], 'unknown')
        with self.assertRaises(PolicyError):
            await self.adapter.respond(status['workerId'], key, 'accept')


if __name__ == '__main__': unittest.main()
