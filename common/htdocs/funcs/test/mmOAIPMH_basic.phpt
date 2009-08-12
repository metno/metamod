--TEST--
MM_OAIPMH class - basic test for OAIPMH functionality
--FILE--
<?php
require_once("../mmConfig.inc");
$mmConfig = MMConfig::getInstance('test_config.txt');
require_once("../mmOAIPMH.inc");

$oaiCorrect = '<?xml version="1.0" encoding="UTF-8"?> 
<OAI-PMH xmlns="http://www.openarchives.org/OAI/2.0/" 
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://www.openarchives.org/OAI/2.0/
         http://www.openarchives.org/OAI/2.0/OAI-PMH.xsd">
  <responseDate>2002-02-08T08:55:46Z</responseDate>
  <request verb="GetRecord" identifier="oai:arXiv.org:cs/0112017"
           metadataPrefix="oai_dc">http://arXiv.org/oai2</request>
  <GetRecord>
   <record> 
    <header>
      <identifier>oai:arXiv.org:cs/0112017</identifier> 
      <datestamp>2001-12-14</datestamp>
      <setSpec>cs</setSpec> 
      <setSpec>math</setSpec>
    </header>
    <metadata>
      <oai_dc:dc 
         xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/" 
         xmlns:dc="http://purl.org/dc/elements/1.1/" 
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
         xsi:schemaLocation="http://www.openarchives.org/OAI/2.0/oai_dc/ 
         http://www.openarchives.org/OAI/2.0/oai_dc.xsd">
        <dc:title>Using Structural Metadata to Localize Experience of 
                  Digital Content</dc:title> 
        <dc:creator>Dushay, Naomi</dc:creator>
        <dc:subject>Digital Libraries</dc:subject> 
        <dc:description>With the increasing technical sophistication of 
            both information consumers and providers, there is 
            increasing demand for more meaningful experiences of digital 
            information. We present a framework that separates digital 
            object experience, or rendering, from digital object storage 
            and manipulation, so the rendering can be tailored to 
            particular communities of users.
        </dc:description> 
        <dc:description>Comment: 23 pages including 2 appendices, 
            8 figures</dc:description> 
        <dc:date>2001-12-14</dc:date>
      </oai_dc:dc>
    </metadata>
  </record>
 </GetRecord>
</OAI-PMH>
';

$oaiCorrectRecordWrong = '<?xml version="1.0" encoding="UTF-8"?> 
<OAI-PMH xmlns="http://www.openarchives.org/OAI/2.0/" 
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://www.openarchives.org/OAI/2.0/
         http://www.openarchives.org/OAI/2.0/OAI-PMH.xsd">
  <responseDate>2002-02-08T08:55:46Z</responseDate>
  <request verb="GetRecord" identifier="oai:arXiv.org:cs/0112017"
           metadataPrefix="oai_dc">http://arXiv.org/oai2</request>
  <GetRecord>
   <record> 
    <header>
      <identifier>oai:arXiv.org:cs/0112017</identifier> 
      <datestamp>2001-12-14</datestamp>
      <setSpec>cs</setSpec> 
      <setSpec>math</setSpec>
    </header>
    <metadata>
      <oai_dc:dc 
         xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/" 
         xmlns:dc="http://purl.org/dc/elements/1.1/" 
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
         xsi:schemaLocation="http://www.openarchives.org/OAI/2.0/oai_dc/ 
         http://www.openarchives.org/OAI/2.0/oai_dc.xsd">
         <dc:wrongElement />
      </oai_dc:dc>
    </metadata>
  </record>
 </GetRecord>
</OAI-PMH>
';

$oaiWrong = '<?xml version="1.0" encoding="UTF-8"?> 
<OAI-PMH xmlns="http://www.openarchives.org/OAI/2.0/" 
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://www.openarchives.org/OAI/2.0/
         http://www.openarchives.org/OAI/2.0/OAI-PMH.xsd">
  <responseDat>2002-02-08T08:55:46Z</responseDat> <!-- this should be responseDate -->
  <request verb="GetRecord" identifier="oai:arXiv.org:cs/0112017"
           metadataPrefix="oai_dc">http://arXiv.org/oai2</request>
  <GetRecord>
   <record> 
    <header>
      <identifier>oai:arXiv.org:cs/0112017</identifier> 
      <datestamp>2001-12-14</datestamp>
      <setSpec>cs</setSpec> 
      <setSpec>math</setSpec>
    </header>
    <metadata>
      <oai_dc:dc 
         xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/" 
         xmlns:dc="http://purl.org/dc/elements/1.1/" 
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
         xsi:schemaLocation="http://www.openarchives.org/OAI/2.0/oai_dc/ 
         http://www.openarchives.org/OAI/2.0/oai_dc.xsd">
         <dc:wrongElement />
      </oai_dc:dc>
    </metadata>
  </record>
 </GetRecord>
</OAI-PMH>
';

$mmOAI = new MM_OaiPmh($oaiCorrect);
if (!$mmOAI instanceof MM_OaiPmh) {
   die ("cannot init MM_OAIPMH, got $mmOAI");
}

if (!$mmOAI->validateOAI()) {
   die ("cannot validate correct oai");
}

if (!$mmOAI->validateRecords()) {
   die ("cannot validate correct records of oai");
}

if ($mmOAI->removeInvalidRecords() != 0) {
   die ("removed records of correct oai");
}

$mmOAIwrongRecord = new MM_OaiPmh($oaiCorrectRecordWrong);
if (!$mmOAIwrongRecord->validateOAI()) {
   die ("cannot validate correct oai with wrong record");
}

if (@$mmOAIwrongRecord->validateRecords()) {
   die ("wrong records should not validate");
}

if (@$mmOAIwrongRecord->removeInvalidRecords() != 1) {
   die ("should remove exactly one record");
}

if (!$mmOAIwrongRecord->validateOAI()) {
   die ("wrongRecord does not validate after record removal");
}
if (!$mmOAIwrongRecord->validateRecords()) {
   die ("wrongRecord still don't validate records after record removal'");
}

$mmOAIwrong = new MM_OaiPmh($oaiWrong);
if (@$mmOAIwrong->validateOAI()) {
   die ("wrong OAI should not validate");
}


?>
--EXPECT--
