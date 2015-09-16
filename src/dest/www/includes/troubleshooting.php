<p><strong><?php echo $appname; ?> is not exporting any shares.</strong></p>
<p>Make sure that the shares are accessible by &quot;Everyone&quot; in Drobo Dashboard.</p>
<p><strong>mount_nfs: can&apos;t mount /ShareNameHere from drobo.ip.address.here onto /some/local/path: Permission denied</strong></p>
<p>Make sure that the remote path is correct. For example, the correct remote path for the &apos;Public&apos; share is <code>/mnt/DroboFS/Shares/Public</code>. In other words, the correct mount call will look like:</p>
<code>mount drobo.ip.address.here:/mnt/DroboFS/Shares/Public /some/local/path</code>