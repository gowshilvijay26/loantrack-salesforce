import { LightningElement } from 'lwc';

export default class LoanCalculator extends LightningElement {
    principal;
    rate;
    tenure;

    emi = 0;
    totalPayable = 0;
    totalInterest = 0;

    showResult = false;
    showError = false;
    errorMessage = '';

    handlePrincipalChange(event) {
        this.principal = event.target.value;
    }

    handleRateChange(event) {
        this.rate = event.target.value;
    }

    handleTenureChange(event) {
        this.tenure = event.target.value;
    }

    calculateEmi() {
        this.showResult = false;
        this.showError = false;

        const p = parseFloat(this.principal);
        const annualRate = parseFloat(this.rate);
        const n = parseInt(this.tenure, 10);

        if (isNaN(p) || p <= 0) {
            this.showValidationError('Please enter a valid Principal Amount.');
            return;
        }
        if (isNaN(annualRate) || annualRate < 0) {
            this.showValidationError('Please enter a valid Interest Rate.');
            return;
        }
        if (isNaN(n) || n <= 0) {
            this.showValidationError('Please enter a valid Tenure in months.');
            return;
        }

        let emiValue;

        if (annualRate === 0) {
            // 0% interest: EMI = P / n
            emiValue = p / n;
        } else {
            const r = annualRate / 12 / 100; // monthly rate
            const factor = Math.pow(1 + r, n);
            emiValue = (p * r * factor) / (factor - 1);
        }

        const totalPayableValue = emiValue * n;
        const totalInterestValue = totalPayableValue - p;

        this.emi = emiValue;
        this.totalPayable = totalPayableValue;
        this.totalInterest = totalInterestValue;

        this.showResult = true;
    }

    showValidationError(message) {
        this.errorMessage = message;
        this.showError = true;
    }

    get emiFormatted() {
        return this.formatCurrency(this.emi);
    }

    get totalPayableFormatted() {
        return this.formatCurrency(this.totalPayable);
    }

    get totalInterestFormatted() {
        return this.formatCurrency(this.totalInterest);
    }

    formatCurrency(value) {
        return '₹' + value.toFixed(2);
    }
}