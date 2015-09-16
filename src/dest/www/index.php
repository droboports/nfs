<?php
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('Cache-Control: post-check=0, pre-check=0', false);
header('Pragma: no-cache');

include('includes/sdkversion.php');
include('includes/publicip.php');
include('includes/variables.php');

$op = $_REQUEST['op'];
switch ($op) {
  case "start":
    unset($out);
    exec("/bin/sh /usr/bin/DroboApps.sh start_app ".$app, $out, $rc);
    if ($rc === 0) {
      $opstatus = "okstart";
    } else {
      $opstatus = "nokstart";
    }
    break;
  case "stop":
    unset($out);
    exec("/bin/sh /usr/bin/DroboApps.sh stop_app ".$app, $out, $rc);
    if ($rc === 0) {
      $opstatus = "okstop";
    } else {
      $opstatus = "nokstop";
    }
    break;
  case "reload":
    unset($out);
    exec("/mnt/DroboFS/Shares/DroboApps/".$app."/service.sh reload", $out, $rc);
    if ($rc === 0) {
      $opstatus = "okreload";
    } else {
      $opstatus = "nokreload";
    }
    break;
  case "logs":
    $opstatus = "logs";
    break;
  default:
    $opstatus = "noop";
    break;
}

include('includes/appstatus.php');
?>
<!DOCTYPE html>
<html lang="en">

<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <meta http-equiv="X-UA-Compatible" content="IE=edge" />
  <meta http-equiv="cache-control" content="no-cache" />
  <meta http-equiv="expires" content="-1" />
  <meta http-equiv="pragma" content="no-cache" />
  <title><?php echo $appname; ?> DroboApp</title>
  <link rel="stylesheet" type="text/css" media="screen" href="css/bootstrap.min.css" />
  <link rel="stylesheet" type="text/css" media="screen" href="css/custom.css" />
  <script src="js/jquery.min.js"></script>
  <script src="js/bootstrap.min.js"></script>
</head>

<body>
<!-- logo bar -->
<nav class="navbar navbar-default navbar-fixed-top">
  <div class="container-fluid">
    <div class="navbar-header">
      <a class="navbar-brand" href="<?php echo $appsite; ?>" target="_new"><img alt="<?php echo $appname; ?>" src="img/app_logo.png" /></a>
    </div>
    <div class="collapse navbar-collapse" id="navbar">
      <ul class="nav navbar-nav navbar-right">
        <li><a class="navbar-brand" href="http://www.drobo.com/" target="_new"><img alt="Drobo" src="img/drobo_logo.png" /></a></li>
      </ul>
    </div>
  </div>
</nav>
<!-- /logo bar -->

<!-- title and button bar -->
<div class="container top-toolbar">
  <div role="toolbar" class="btn-toolbar">
    <div role="group" class="btn-group">
      <p class="title">About <?php echo $app; ?> <?php echo $appversion; ?></p>
    </div>
    <div role="group" class="btn-group pull-right">
<?php if ($apprunning) { ?>
      <a role="button" class="btn btn-primary" href="?op=stop" onclick="$('#pleaseWaitDialog').modal(); return true"><span class="glyphicon glyphicon-stop"></span> Stop</a>
<?php if ($apppage) { ?>
      <a role="button" class="btn btn-primary" href="<?php echo $apppage; ?>" target="_new"><span class="glyphicon glyphicon-globe"></span> Go to App</a>
<?php } ?>
<?php } else { ?>
      <a role="button" class="btn btn-primary" href="?op=start" onclick="$('#pleaseWaitDialog').modal(); return true"><span class="glyphicon glyphicon-play"></span> Start</a>
<?php if ($apppage) { ?>
      <a role="button" class="btn btn-primary disabled" href="<?php echo $apppage; ?>" target="_new"><span class="glyphicon glyphicon-globe"></span> Go to App</a>
<?php } ?>
<?php } ?>
      <a role="button" class="btn btn-primary" href="<?php echo $apphelp; ?>" target="_new"><span class="glyphicon glyphicon-question-sign"></span> Help</a>
    </div>
  </div>
</div>
<!-- /title bar -->

<!-- operation modal wait -->
<div role="dialog" id="pleaseWaitDialog" class="modal animated bounceIn" tabindex="-1" aria-labelledby="myModalLabel" aria-hidden="true">
  <div class="modal-dialog">
    <div class="modal-content">
      <div class="modal-body">
        <p id="myModalLabel">Operation in progress... please wait.</p>
        <div class="progress">
          <div class="progress-bar progress-bar-striped active" aria-valuenow="100" aria-valuemin="0" aria-valuemax="100" style="width: 100%">
          </div>
        </div>
      </div>
    </div>
  </div>
</div>
<!-- /operation modal wait -->

<!-- page sections -->
<div class="container">

<!-- operation feedback -->
  <div class="row">
    <div class="col-xs-3"></div>
    <div class="col-xs-6">
<?php switch ($opstatus) { ?>
<?php case "okstart": ?>
      <div class="alert alert-success fade in" id="opstatus">
        <a href="#" class="close" data-dismiss="alert" aria-label="close">&times;</a>
        <?php echo $appname; ?> was successfully started.
      </div>
<?php break; case "nokstart": ?>
      <div class="alert alert-danger fade in" id="opstatus">
        <a href="#" class="close" data-dismiss="alert" aria-label="close">&times;</a>
        <?php echo $appname; ?> failed to start. See logs below for more information.
      </div>
<?php break; case "okstop": ?>
      <div class="alert alert-success fade in" id="opstatus">
        <a href="#" class="close" data-dismiss="alert" aria-label="close">&times;</a>
        <?php echo $appname; ?> was successfully stopped.
      </div>
<?php break; case "nokstop": ?>
      <div class="alert alert-danger fade in" id="opstatus">
        <a href="#" class="close" data-dismiss="alert" aria-label="close">&times;</a>
        <?php echo $appname; ?> failed to stop. See logs below for more information.
      </div>
<?php break; case "okreload": ?>
      <div class="alert alert-success fade in" id="opstatus">
        <a href="#" class="close" data-dismiss="alert" aria-label="close">&times;</a>
        <?php echo $appname; ?> was successfully reloaded.
      </div>
<?php break; case "nokreload": ?>
      <div class="alert alert-danger fade in" id="opstatus">
        <a href="#" class="close" data-dismiss="alert" aria-label="close">&times;</a>
        <?php echo $appname; ?> failed to reload. See logs below for more information.
      </div>
<?php break; } ?>
      <script>
      window.setTimeout(function() {
        $("#opstatus").fadeTo(500, 0).slideUp(500, function() {
          $(this).remove(); 
        });
      }, 2000);
      </script>
    </div><!-- col -->
    <div class="col-xs-3"></div>
  </div><!-- row -->
<!-- /operation feedback -->

  <div class="row">
    <div class="col-xs-12">

  <!-- description -->
  <div class="panel-group" id="description">
    <div class="panel panel-default">
      <div class="panel-heading">
        <h4 class="panel-title"><a data-toggle="collapse" data-parent="#description" href="#descriptionbody">Description</a></h4>
      </div>
      <div id="descriptionbody" class="panel-collapse collapse in">
        <div class="panel-body">
<?php include('includes/description.php'); ?>
          <div class="pull-right">
            <a role="button" class="btn btn-default" href="<?php echo $appsite; ?>" target="_new"><span class="glyphicon glyphicon-globe"></span> Learn more about <?php echo $appname; ?></a>
          </div>
        </div>
      </div>
    </div>
  </div>

  <!-- getting started -->
  <div class="panel-group" id="gettingstarted">
    <div class="panel panel-default">
      <div class="panel-heading">
        <h4 class="panel-title"><a data-toggle="collapse" data-parent="#gettingstarted" href="#gettingstartedbody">Getting started</a></h4>
      </div>
      <div id="gettingstartedbody" class="panel-collapse collapse in">
        <div class="panel-body">
<?php if ($apppage) { ?>
          <p>To access <?php echo $appname; ?> on your Drobo click the &quot;Go to App&quot; button above.</p>
<?php } ?>
<?php include('includes/https.php'); ?>
<?php include('includes/gettingstarted.php'); ?>
        </div>
      </div>
    </div>
  </div>

  <!-- next steps -->
  <div class="panel-group" id="nextsteps">
    <div class="panel panel-default">
      <div class="panel-heading">
        <h4 class="panel-title"><a data-toggle="collapse" data-parent="#nextsteps" href="#nextstepsbody">Next steps</a></h4>
      </div>
      <div id="nextstepsbody" class="panel-collapse collapse in">
        <div class="panel-body">
<?php include('includes/nextsteps.php'); ?>
<?php include('includes/ports.php'); ?>
<?php include('includes/publicurl.php'); ?>
<?php include('includes/ssl.php'); ?>
        </div>
      </div>
    </div>
  </div>

  <!-- troubleshooting -->
  <div class="panel-group" id="troubleshooting">
    <div class="panel panel-default">
      <div class="panel-heading">
        <h4 class="panel-title"><a data-toggle="collapse" data-parent="#troubleshooting" href="#troubleshootingbody">Troubleshooting</a></h4>
      </div>
      <div id="troubleshootingbody" class="panel-collapse collapse">
        <div class="panel-body">
<?php include('includes/troubleconnect.php'); ?>
<?php include('includes/troubleshooting.php'); ?>
        </div>
      </div>
    </div>
  </div>

  <!-- logfiles -->
  <div class="panel-group" id="logfiles">
    <div class="panel panel-default">
      <div class="panel-heading">
        <h4 class="panel-title"><a data-toggle="collapse" data-parent="#logfiles" href="#logfilesbody">Log information</a></h4>
      </div>
      <div id="logfilesbody" class="panel-collapse collapse <?php if ($opstatus == "logs") { ?>in<?php } ?>">
        <div class="panel-body">
<?php include('includes/logfiles.php'); ?>
        </div>
      </div>
    </div>
  </div>

  <!-- changelog -->
  <div class="panel-group" id="changelog">
    <div class="panel panel-default">
      <div class="panel-heading">
        <h4 class="panel-title"><a data-toggle="collapse" data-parent="#changelog" href="#changelogbody">Summary of changes</a></h4>
      </div>
      <div id="changelogbody" class="panel-collapse collapse">
        <div class="panel-body">
<?php include('includes/changelog.php'); ?>
        </div>
      </div>
    </div>
  </div>

    </div><!-- col -->
  </div><!-- row -->
</div><!-- container -->
<!-- /page sections -->

<footer>
  <div class="container">
    <div class="pull-right">
      <small>All copyrighted materials and trademarks are the property of their respective owners.</small>
    </div>
  </div>
</footer>
</body>
</html>
