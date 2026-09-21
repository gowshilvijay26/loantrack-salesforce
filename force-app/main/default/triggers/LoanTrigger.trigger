trigger LoanTrigger on Loan__c (before insert, before update, after insert, after update) {
    if (Trigger.isBefore) {
        LoanTriggerHandler.beforeSave(Trigger.new, Trigger.oldMap);
    } else {
        LoanTriggerHandler.afterSave(Trigger.new, Trigger.oldMap);
    }
}