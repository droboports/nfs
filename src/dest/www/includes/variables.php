<?php 
$app = "nfs";
$appname = "NFS";
$appversion = "1.3.3";
$appsite = "http://nfs.sourceforge.net/";
$apphelp = "http://sourceforge.net/p/nfs/discussion/133302/";

$applogs = array("/tmp/DroboApps/".$app."/log.txt");
$appconf = "/mnt/DroboFS/Shares/DroboApps/".$app."/etc/exports";
$appautoconf = "/mnt/DroboFS/Shares/DroboApps/".$app."/etc/exports.auto";

// $appprotos = array("http");
// $appports = array("8200");
// $droboip = $_SERVER['SERVER_ADDR'];
// $apppage = $appprotos[0]."://".$droboip.":".$appports[0]."/";
// if ($publicip != "") {
//   $publicurl = $appprotos[0]."://".$publicip.":".$appports[0]."/";
// } else {
//   $publicurl = $appprotos[0]."://public.ip.address.here:".$appports[0]."/";
// }
// $portscansite = "http://mxtoolbox.com/SuperTool.aspx?action=scan%3a".$publicip."&run=toolpage";
?>
