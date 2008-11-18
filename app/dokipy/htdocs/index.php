<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
   <title>[==APPLICATION_NAME==]</title>
   <meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1" />
   <link href="style.css" rel="stylesheet" type="text/css" />
</head>
<body>
<div class="mybody">
   <div class="myheader">
   [==APP_HEADER_HTML==]
   </div>
   <table class="main_structure" cellpadding="0" cellspacing="0">
      <tr>
         <td class="main_menu">
            <?php
               $s1 = <<<END_OF_STRING
[==APP_MENU==]
END_OF_STRING;
               $a1 = explode("\n",$s1);
               foreach ($a1 as $s2) {
                  if (preg_match ('/^ *([^ ]+) (.*)$/i',$s2,$a2)) {
                     echo '<a class="mm_item" href="' . $a2[1] . '">' . $a2[2] . "</a>\n";
                  }
               }
            ?>
            <br />
         </td>
         <td>&nbsp;
         </td>
      </tr>
   </table>
   [==APP_FOOTER_HTML==]
</div>
</body>
</html>
