trigger PaymentTrigger on Payment__c (after insert) {
    PaymentTriggerHandler.afterInsert(Trigger.new);
}