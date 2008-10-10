<?php
#   
#      Class definition
#   
   class buildxml {
      var $partialxml;   # Object member
      var $lastpath;   # Object member
      var $teststring;   # Object member
      function add($path, $value) {
#      
         $teststring = "";
         $lastpath = $this->lastpath;
         $indent = $this->initialindent;
         $incrin = $this->incrindent;
         $partialxml = "";
         $path_hasatt = strlen($path) > 0 && substr($path,-1,1) == '=';
         $breakpos = -1;
         if (strlen($path) > 0) {
            $patharr = explode(" ",$path);
            $i1 = 0;
            foreach ($patharr as $pathelt) {
               if (substr($pathelt,0,1) == '*') {
                  $breakpos = $i1;
                  $patharr[$i1] = substr($pathelt,1);
               }
               $i1++;
            }
         } else {
            $patharr = array();
         }
         $pathend = count($patharr)-1;
#            
         $lastpath_hasatt = strlen($lastpath) > 0 && substr($lastpath,-1,1) == '=';
         if (strlen($lastpath) > 0) {
            $lastpatharr = explode(" ",$lastpath);
            $i1 = 0;
            foreach ($lastpatharr as $pathelt) {
               if (substr($pathelt,0,1) == '*') {
                  $lastpatharr[$i1] = substr($pathelt,1);
               }
               $i1++;
            }
         } else {
            $lastpatharr = array();
         }
         $lastpathend = count($lastpatharr)-1;
#   
         $startdiff = 0;
         while ($startdiff <= $pathend && $startdiff <= $lastpathend
                && $patharr[$startdiff] == $lastpatharr[$startdiff]) {
            $startdiff++;
         }
         if ($breakpos >= 0 && $breakpos < $startdiff) {
            $startdiff = $breakpos;
         }
         if ($lastpath_hasatt) { # Lastpath has attribute
            if ($path_hasatt && $lastpathend == $pathend && $startdiff == $pathend) {
#   
#              Lastpath: a b c=
#              Path:     a b d=
#   
               $partialxml .= " " . $patharr[$pathend] . '"' . $value . '"'; $teststring .= " 36";
            } else {
               if ($pathend >= $lastpathend && $startdiff >= $lastpathend) {
#   
#                 Lastpath: a b c=
#                 Path:     a b d e
#   
                  $partialxml .= ">\n"; $teststring .= " 43";
                  if ($path_hasatt) {
                     for ($i1=$lastpathend; $i1 < $pathend-1; $i1++) {
                        $partialxml .= str_pad('', $indent+$incrin*$i1).'<'.$patharr[$i1].'>'."\n"; $teststring .= " 45";
                     }
                     $partialxml .= str_pad('', $indent+$incrin*($pathend-1)).'<'.$patharr[$pathend-1].
                                    ' '.$patharr[$pathend].'"'.$value.'"'; $teststring .= " 49";
                  } else {
                     for ($i1=$lastpathend; $i1 <= $pathend-1; $i1++) {
                        $partialxml .= str_pad('', $indent+$incrin*$i1).'<'.$patharr[$i1].'>'."\n"; $teststring .= " 52";
                     }
                     $partialxml .= str_pad('', $indent+$incrin*($pathend)).'<'.$patharr[$pathend].'>'.$value.
                                    '</'.$patharr[$pathend].'>'."\n"; $teststring .= " 54";
                  }
               } else if ($path_hasatt) {
#   
#                 Lastpath: a b c d=
#                 Path:     a e f=
#   
                  $partialxml .= "/>\n"; $teststring .= " 61";
                  $istart = $startdiff;
                  if ($istart < 0) $istart = 0;
                  for ($i1=$lastpathend-2; $i1 >= $istart; $i1--) {
                     $partialxml .= str_pad('', $indent+$incrin*$i1).'</'.$lastpatharr[$i1].'>'."\n"; $teststring .= " 65";
                  }
                  for ($i1=$istart; $i1 <= $pathend-2; $i1++) {
                     $partialxml .= str_pad('', $indent+$incrin*$i1).'<'.$patharr[$i1].'>'."\n"; $teststring .= " 68";
                  }
                  $partialxml .= str_pad('', $indent+$incrin*($pathend-1)).'<'.$patharr[$pathend-1].
                                 ' '.$patharr[$pathend].'"'.$value.'"'; $teststring .= " 71";
               } else {
#   
#                 Lastpath: a b c=
#                 Path:     a b          (evt.  a d)
#   
                  if ($startdiff == $lastpathend) {
                     $partialxml .= '>'.$value.'</'.$patharr[$pathend].'>'."\n"; $teststring .= " 77";
                  } else {
                     $partialxml .= "/>\n"; $teststring .= " 78";
                     for ($i1=$lastpathend-2; $i1 >= $startdiff; $i1--) {
                        $partialxml .= str_pad('', $indent+$incrin*$i1).'</'.$lastpatharr[$i1].'>'."\n"; $teststring .= " 79";
                     }
                     if ($pathend >= 0 && $pathend == $startdiff-1 && $pathend < $lastpathend-1) {
                        $partialxml .= str_pad('', $indent+$incrin*$pathend).'</'.$lastpatharr[$pathend].'>'.
                                       "\n"; $teststring .= " 82";
                        $partialxml .= str_pad('', $indent+$incrin*$pathend).'<'.$patharr[$pathend].'>'.
                                       $value.'</'.$patharr[$i1].'>'."\n"; $teststring .= " 83";
                     } else {
                        $istart = $startdiff-1;
                        if ($istart < 0) $istart = 0;
                        if ($pathend >= $startdiff) $istart = $startdiff;
                        for ($i1=$istart; $i1 < $pathend; $i1++) {
                           $partialxml .= str_pad('', $indent+$incrin*$i1).'<'.$patharr[$i1].'>'."\n"; $teststring .= " 92";
                        }
                        if ($istart <= $pathend) {
                           $partialxml .= str_pad('', $indent+$incrin*$i1).'<'.$patharr[$pathend].'>'.$value.
                                          '</'.$patharr[$pathend].'>'."\n"; $teststring .= " 95";
                        }
                     }
                  }
               }
            }
         } else { # Lastpath has no attribute:
            if ($pathend == $lastpathend && $startdiff > $lastpathend && !$path_hasatt) {
#   
#              lastpath: a b c
#              path:     a b c
#   
               $partialxml .= str_pad('', $indent+$incrin*$pathend).'<'.$patharr[$pathend].'>'; $teststring .= " 106";
               $partialxml .= $value.'</'.$patharr[$pathend].'>'."\n"; $teststring .= " 107";
            } else if ($pathend > $lastpathend && $startdiff > $lastpathend) {
#   
#              lastpath: a b c
#              path:     a b c d e      (evt. a b c d e=)
#   
               for ($i1=$lastpathend+1; $i1 < $pathend-1; $i1++) {
                  $partialxml .= str_pad('', $indent+$incrin*$i1).'<'.$patharr[$i1].'>'."\n"; $teststring .= " 117";
               }
               if ($path_hasatt) {
                  $partialxml .= str_pad('', $indent+$incrin*($pathend-1)).'<'.$patharr[$pathend-1].
                                 ' '.$patharr[$pathend].'"'.$value.'"'; $teststring .= " 118";
               } else {
                  if ($pathend > 0) {
                     $partialxml .= str_pad('', $indent+$incrin*($pathend-1)).
                                    '<'.$patharr[$pathend-1].'>'."\n"; $teststring .= " 121";
                  }
                  $partialxml .= str_pad('', $indent+$incrin*$pathend).'<'.$patharr[$pathend].'>'.$value.
                                 '</'.$patharr[$pathend].'>'."\n"; $teststring .= " 123";
               }
            } else if (!$path_hasatt) {
#   
#              lastpath: a b c
#              path:     a b      (evt. a b x)
#   
               for ($i1=$lastpathend-1; $i1 >= $startdiff; $i1--) {
                  $partialxml .= str_pad('', $indent+$incrin*$i1).'</'.$lastpatharr[$i1].'>'."\n"; $teststring .= " 134";
               }
               if ($pathend >= 0 && $pathend == $startdiff-1 && $pathend < $lastpathend) {
                  $partialxml .= str_pad('', $indent+$incrin*$pathend).'</'.$lastpatharr[$pathend].'>'."\n"; $teststring .= " 137";
                  $partialxml .= str_pad('', $indent+$incrin*$pathend).'<'.$patharr[$pathend].'>'; $teststring .= " 138";
                  $partialxml .= $value.'</'.$patharr[$pathend].'>'."\n"; $teststring .= " 139";
               } else {
                  for ($i1=$startdiff; $i1 < $pathend; $i1++) {
                     $partialxml .= str_pad('', $indent+$incrin*$i1).'<'.$patharr[$i1].'>'."\n"; $teststring .= " 142";
                  }
                  if ($pathend >= 0) {
                     $partialxml .= str_pad('', $indent+$incrin*$pathend).'<'.$patharr[$pathend].'>'; $teststring .= " 145";
                     $partialxml .= $value.'</'.$patharr[$pathend].'>'."\n"; $teststring .= " 146";
                  }
               }
            } else {
#   
#              lastpath: a b c
#              path:     a x=
#   
               $istart = $startdiff;
               if ($pathend == $startdiff) $istart = $startdiff-1;
               if ($istart < 0) $istart = 0;
               for ($i1=$lastpathend-1; $i1 >= $istart; $i1--) {
                  $partialxml .= str_pad('', $indent+$incrin*$i1).'</'.$lastpatharr[$i1].'>'."\n"; $teststring .= " 160";
               }
               for ($i1=$istart; $i1 <= $pathend-2; $i1++) {
                  $partialxml .= str_pad('', $indent+$incrin*$i1).'<'.$patharr[$i1].'>'."\n"; $teststring .= " 163";
               }
               $partialxml .= str_pad('', $indent+$incrin*($pathend-1)).'<'.$patharr[$pathend-1];
               $partialxml .= " ".$patharr[$pathend].'"'.$value.'"'; $teststring .= " 166";
            }
         }
         $this->lastpath = $path;
         $this->partialxml .= $partialxml;
         $this->teststring = $teststring;
         return 1;
      }
      function test() {
         $fname = 'buildxml.out';
         $testdata = array(
                          'a', 'v1',
                          'b', 'v1',
                          'a b', 'v1',
                          'a x=', 'v2',
                          'a y=', 'v3',
                          'a b c d j e=', 'v4',
                          'a f g h c=', 'v5',
                          'a b c', 'v6',
                          'a *b c', 'v7',
                          'a b c d j e=', 'v8',
                          'a b c d *j e=', 'v9',
                          'a b c', 'v10',
                          'a b c *d', 'v11',
                          'a b c *d e=', 'v12',
                          '', ''
                          );
         $FIL = fopen($fname,'w');
         $testcount = count($testdata);
         for ($i1=0; $i1 < $testcount; $i1 += 2) {
            $this->add($testdata[$i1],$testdata[$i1+1]);
            $xmlout = $this->get();
            fputs($FIL,$testdata[$i1]."    ".$testdata[$i1+1]."\n");
            fputs($FIL,$xmlout . "\n--------------" . $this->teststring . "\n");
         }
         fclose($FIL);
         return 1;
      }
      function get() {
         return $this->partialxml;
      }
      function buildxml($initialindent = 0, $incrindent = 2) {   # Constructor function
         $this->initialindent = $initialindent;
         $this->incrindent = $incrindent;
         $this->partialxml = '';
         $this->lastpath = '';
         $this->teststring = '';
      }
   }
?>
