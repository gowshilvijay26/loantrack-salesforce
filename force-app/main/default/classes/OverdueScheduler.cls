public with sharing class OverdueScheduler implements Schedulable {

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new OverdueInstallmentBatch(), 200);
    }
}