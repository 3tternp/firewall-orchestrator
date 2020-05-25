<?php
	$stamm="";
	require_once ("db-input.php");
	if (isset($_SESSION)) session_destroy();
	session_start();
	require_once ("db-input.php");
	$cleaner = new DbInput();  // for clean-function
	setlocale(LC_CTYPE, "de_DE.UTF-8");
	$request = $cleaner->clean_structure($_REQUEST);
	$session = $cleaner->clean_structure($_SESSION);
?>
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
<title>Firewall Orchestrator Login</title>
<meta name="robots" content="index,follow">
<meta http-equiv="cache-control" content="no-cache">
<meta name="revisit-after" content="2 days">
<meta http-equiv="content-language" content="de">

<link rel="stylesheet" type="text/css" href="<?php echo $stamm ?>css/firewall.css">
</head>
<body class="index" onLoad="document.login.Username.focus();">
<div id="farbe_oben"><img src="<?php echo $stamm ?>img/1p_tr.gif" width="100%" height="10"></div>
<div style="position:absolute;top:33px;left:0px;z-index:100;">
<table width="100%" cellpadding="0" cellspacing="0"><tr>
 <td style="height:2px;width:100%;background:url(<?php echo $stamm ?>img/linie_h_d.gif) repeat-x;"><img src="<?php echo $stamm ?>img/1p_tr.gif" height="2" width="100%"></td>
</tr></table></div>
<p>
 &nbsp;</p><p>
 &nbsp;</p>
 <form name="login" action="index2.php" method="POST">
 <table align="center">
	<tr><td><a href="http://www.cactus.de" target="_blank"><img src="<?php echo $stamm ?>img/cactus_logo.gif" width="187" height="67"></a></td></tr>
	<tr><td width="50">&nbsp;</td></tr>
 	<tr><td><h2>Firewall Orchestrator</h2></td></tr>
 </table>
 <p>
 &nbsp;</p><p>
 &nbsp;</p>
 <table align="center"><tr>
   <td>Username:&nbsp;&nbsp;</td>
   <td><input type="text" name="Username" class="diff" tabindex="1"></td>
 </tr><tr>
   <td>Password:&nbsp;&nbsp;</td>
   <td><input type="password" name="Passwort" class="diff" tabindex="2"></td>
 </tr><tr>
   <td>&nbsp;</td>
   <td><input type="submit" value="Login" class="button" tabindex="3"></td>
 </tr>
 <?php
 	if (isset($request['failure'])) $login_fehler = $request['failure'];
	if (isset($login_fehler)) {
 		if ($login_fehler == 'wrong_creds') {
 			echo "<tr><td>&nbsp;</td></td>" . 
				"<tr><td colspan=\"2\"><b>" . "wrong credentials" . "</b></td></tr>";
 		} elseif ($login_fehler == 'expired') {
 			echo "<tr><td>&nbsp;</td></td>" . 
				"<tr><td colspan=\"2\">" . 
				"<b>" . "account expired" . "</b></td></tr>";			
 		} elseif ($login_fehler == 'superuser_login') {
 			echo "<tr><td>&nbsp;</td></td>" . 
				"<tr><td colspan=\"2\">" . 
				"<b>" . "wrong credentials" . "</b></td></tr>";			
 		} else {
 			echo "<tr><td>&nbsp;</td></td>" . 
				"<tr><td colspan=\"2\">" . 
				"<b>" . "wrong credentials" . "</b></td></tr>";			
 		} 
	}
?>
 
 </table>
 </form>
</body></html>