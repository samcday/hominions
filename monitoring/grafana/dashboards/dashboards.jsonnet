local etcd = (import "mixin/mixin.libsonnet").grafanaDashboards;
local nodeExporter = (import "node-mixin/mixin.libsonnet") {
  _config+:: {
    nodeExporterSelector: 'job="node-exporter"',
    showMultiCluster: true,
  },
}.grafanaDashboards;
local kubernetes = (import "kubernetes-mixin/mixin.libsonnet") {
  _config+:: {
    cadvisorSelector: 'job="kubelet"',
    diskDeviceSelector: 'device=~"/dev/(%s)"' % std.join('|', self.diskDevices),
    kubeApiserverSelector: 'job="apiserver"',
    showMultiCluster: true,
  },
}.grafanaDashboards;
local prometheus = (import 'prometheus-mixin/mixin.libsonnet').grafanaDashboards;

{
  ["etcd/" + name]: etcd[name] for name in std.objectFields(etcd)
}+
{
  ["node-exporter/" + name]: nodeExporter[name] for name in std.objectFields(nodeExporter)
}+
{
  ["kubernetes/" + name]: kubernetes[name] for name in std.objectFields(kubernetes)
}+
{
  ["prometheus/" + name]: prometheus[name] for name in std.objectFields(prometheus)
}
