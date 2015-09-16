<p><?php echo $appname; ?> is a self-configuring app. It will retrieve a list of all the shares in the Drobo, and serve them automatically unless a manual configuration is provided.</p>
<p>Since <?php echo $appname; ?> does not support per-user authentication, shares are automatically served only if they are configured in Drobo Dashboard to be accessible by &quot;Everyone&quot;, either read/write or read only.</p>
<?php if (file_exists($appautoconf)) { ?>
  <p><?php echo $appname; ?> is currently automatically configured. This is the content of <code><?php echo $appconf; ?></code>:</p>
  <pre class="pre-scrollable">
<?php echo file_get_contents($appconf); ?>
  </pre>
  <p>The &quot;Rescan&quot; button will force an update of the share list.</p>
  <a role="button" class="btn btn-default" href="?op=reload" onclick="$('#pleaseWaitDialog').modal(); return true"><span class="glyphicon glyphicon-refresh"></span> Rescan</a>
<?php } elseif (file_exists($appconf)) { ?>
  <p><?php echo $appname; ?> is currently manually configured. This is the content of <code><?php echo $appconf; ?></code>:</p>
  <pre class="pre-scrollable">
<?php echo file_get_contents($appconf); ?>
  </pre>
<?php } else { ?>
  <p><?php echo $appname; ?> is currently not configured. Please click the &quot;Rescan&quot; button to generate an automatic configuration.</p>
  <a role="button" class="btn btn-default" href="?op=reload" onclick="$('#pleaseWaitDialog').modal(); return true"><span class="glyphicon glyphicon-refresh"></span> Rescan</a>
<?php } ?>