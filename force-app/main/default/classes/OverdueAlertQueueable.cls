public class OverdueAlertQueueable implements Queueable, Database.AllowsCallouts {

    private List<Id> installmentIds;

    public OverdueAlertQueueable(List<Id> installmentIds) {
        this.installmentIds = installmentIds;
    }

    public void execute(QueueableContext context) {

        List<Installment__c> installments = [
            SELECT Id, Name, Due_Date__c, EMI_Amount__c, Late_Fee__c,
                   Balance_Due__c, Status__c,
                   Loan__c, Loan__r.Name, Loan__r.Status__c,
                   Loan__r.Client__c, Loan__r.Client__r.Name
            FROM Installment__c
            WHERE Id IN :installmentIds
        ];

        List<String> failedIds = new List<String>();

        for (Installment__c inst : installments) {

            Map<String, Object> payload = new Map<String, Object>{
                'installmentId'   => inst.Id,
                'installmentName' => inst.Name,
                'loanId'          => inst.Loan__c,
                'loanName'        => inst.Loan__r.Name,
                'clientName'      => inst.Loan__r.Client__r.Name,
                'dueDate'         => inst.Due_Date__c,
                'emiAmount'       => inst.EMI_Amount__c,
                'lateFee'         => inst.Late_Fee__c,
                'balanceDue'      => inst.Balance_Due__c,
                'status'          => inst.Status__c
            };

            String jsonBody = JSON.serialize(payload);

            try {
                HttpRequest req = new HttpRequest();
                req.setEndpoint('callout:Webhook_Site_NC');
                req.setMethod('POST');
                req.setHeader('Content-Type', 'application/json');
                req.setBody(jsonBody);
                req.setTimeout(10000);

                Http http = new Http();
                HttpResponse res = http.send(req);

                if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
                    System.debug('Overdue alert sent successfully for Installment: ' + inst.Id
                                  + ' | Status Code: ' + res.getStatusCode());
                } else {
                    System.debug(LoggingLevel.WARN, 'Overdue alert callout returned non-success status for Installment: '
                                  + inst.Id + ' | Status Code: ' + res.getStatusCode()
                                  + ' | Body: ' + res.getBody());
                    failedIds.add(inst.Id);
                }

            } catch (Exception ex) {
                System.debug(LoggingLevel.ERROR, 'Overdue alert callout failed for Installment: ' + inst.Id
                              + ' | Error: ' + ex.getMessage());
                failedIds.add(inst.Id);
            }
        }

        if (!failedIds.isEmpty()) {
            System.debug(LoggingLevel.ERROR, 'Failed to send overdue alerts for Installment Ids: ' + failedIds);
        }
    }
}