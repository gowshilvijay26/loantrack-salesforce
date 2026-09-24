import { LightningElement, api, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getInstallments from '@salesforce/apex/InstallmentScheduleController.getInstallments';
import recordPayment from '@salesforce/apex/InstallmentScheduleController.recordPayment';

const COLUMNS = [
    { label: 'No.', fieldName: 'installmentNumber', type: 'number', initialWidth: 70 },
    { label: 'Due Date', fieldName: 'dueDate', type: 'date-local' },
    { label: 'EMI Amount', fieldName: 'emiAmount', type: 'currency' },
    { label: 'Paid', fieldName: 'amountPaid', type: 'currency' },
    { label: 'Balance', fieldName: 'balanceDue', type: 'currency' },
    {
        label: 'Status', fieldName: 'status', type: 'badge',
        typeAttributes: { variant: { fieldName: 'badgeVariant' } }
    },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [{ label: 'Record Payment', name: 'record_payment' }]
        }
    }
];

export default class InstallmentSchedule extends LightningElement {
    @api recordId;

    columns = COLUMNS;
    installments;
    error;
    wiredResult;

    showModal = false;
    selectedInstallmentId;
    selectedInstallmentName;
    selectedBalanceDue = 0;
    paymentAmount;
    paymentMode = 'UPI';
    modalError;
    isSaving = false;

    paymentModeOptions = [
        { label: 'Cash', value: 'Cash' },
        { label: 'UPI', value: 'UPI' },
        { label: 'Bank Transfer', value: 'Bank Transfer' },
        { label: 'Cheque', value: 'Cheque' }
    ];

    @wire(getInstallments, { loanId: '$recordId' })
    wiredInstallments(result) {
        this.wiredResult = result;
        if (result.data) {
            this.installments = result.data;
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error.body ? result.error.body.message : result.error.message;
            this.installments = undefined;
        }
    }

    get tableData() {
        return this.installments ? this.installments : [];
    }

    get selectedBalanceDueFormatted() {
        return '₹' + Number(this.selectedBalanceDue).toFixed(2);
    }

    handleRowAction(event) {
        const row = event.detail.row;
        this.selectedInstallmentId = row.id;
        this.selectedInstallmentName = row.name;
        this.selectedBalanceDue = row.balanceDue;
        this.paymentAmount = row.balanceDue;
        this.paymentMode = 'UPI';
        this.modalError = undefined;
        this.showModal = true;
    }

    handleAmountChange(event) {
        this.paymentAmount = event.target.value;
    }

    handleModeChange(event) {
        this.paymentMode = event.target.value;
    }

    closeModal() {
        this.showModal = false;
    }

    async submitPayment() {
        this.modalError = undefined;
        const amount = parseFloat(this.paymentAmount);

        if (isNaN(amount) || amount <= 0) {
            this.modalError = 'Please enter a valid payment amount.';
            return;
        }

        this.isSaving = true;
        try {
            await recordPayment({
                installmentId: this.selectedInstallmentId,
                loanId: this.recordId,
                amount: amount,
                paymentMode: this.paymentMode
            });
            this.showModal = false;
            await refreshApex(this.wiredResult);
        } catch (e) {
            this.modalError = e.body ? e.body.message : e.message;
        } finally {
            this.isSaving = false;
        }
    }
}