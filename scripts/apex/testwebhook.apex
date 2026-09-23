HttpRequest req = new HttpRequest();
req.setEndpoint('callout:Webhook_Site_NC');
req.setMethod('POST');
req.setHeader('Content-Type', 'application/json');
req.setBody('{"test":"Hello from LoanTrack Apex","loan":"LN-0020","status":"Overdue"}');

Http http = new Http();
HTTPResponse res = http.send(req);

System.debug('Status Code: ' + res.getStatusCode());
System.debug('Response Body: ' + res.getBody());