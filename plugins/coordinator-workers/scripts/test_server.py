import json
import unittest

from policy import PolicyError
from server import MCPServer


class StubAdapter:
    def status(self, worker_id): return {'workerId': worker_id, 'status': 'completed'}


class ServerTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self): self.server = MCPServer(StubAdapter())

    async def test_mcp_initialization_and_tool_discovery(self):
        response = await self.server.dispatch({'method': 'initialize'})
        self.assertIn('tools', response['capabilities'])
        tools = (await self.server.dispatch({'method': 'tools/list'}))['tools']
        self.assertEqual(len(tools), 6)
        self.assertTrue(next(t for t in tools if t['name']=='worker_status')['annotations']['readOnlyHint'])

    async def test_status_serializes_without_internal_objects(self):
        response = await self.server.dispatch({'method': 'tools/call',
            'params': {'name':'worker_status','arguments':{'workerId':'worker-1'}}})
        self.assertEqual(json.loads(response['content'][0]['text'])['status'], 'completed')

    async def test_reject_arbitrary_config_and_unknown_tool(self):
        for name, args in [('worker_start', {'assignment':'review','model':'test','effort':'high',
                                            'prompt':'test','config':{'sandbox':'danger-full-access'}}),
                           ('raw_rpc', {'method':'config/value/write'})]:
            with self.assertRaises(PolicyError):
                await self.server.dispatch({'method':'tools/call','params':{'name':name,'arguments':args}})


if __name__ == '__main__': unittest.main()
