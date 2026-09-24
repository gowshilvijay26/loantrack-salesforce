import { LightningElement, api, wire } from 'lwc';
import getLoanSummary from '@salesforce/apex/LoanSummaryController.getLoanSummary';

export default class LoanSummaryCard extends LightningElement {
    @api recordId; // automatically set when placed on a Loan record page

    summary;
    error;

    @wire(getLoanSummary, { loanId: '$recordId' })
    wiredSummary({ data, error }) {
        if (data) {
            this.summary = data;
            this.error = undefined;
        } else if (error) {
            this.error = error.body ? error.body.message : error.message;
            this.summary = undefined;
        }
    }

    get outstandingFormatted() {
        return this.summary ? this.formatCurrency(this.summary.outstandingAmount) : '';
    }

    get nextDueDateFormatted() {
        if (!this.summary || !this.summary.nextDueDate) {
            return 'No upcoming EMI';
        }
        return new Date(this.summary.nextDueDate + 'T00:00:00').toLocaleDateString('en-IN', {
            year: 'numeric', month: 'short', day: 'numeric'
        });
    }

    get hasOverdue() {
        return this.summary && this.summary.overdueCount > 0;
    }

    get overdueMessage() {
        return this.summary ? `${this.summary.overdueCount} installment(s) overdue` : '';
    }

    formatCurrency(value) {
        return '₹' + Number(value).toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
    }
}