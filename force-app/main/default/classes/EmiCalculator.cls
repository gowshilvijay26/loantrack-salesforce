public with sharing class EmiCalculator {

    public class EmiException extends Exception {}

    /**
     * Annual rate (12 = 12%) -> monthly rate as a decimal (0.01).
     * The Installment logic in the trigger handler reuses this.
     */
    public static Decimal monthlyRate(Decimal annualRate) {
        if (annualRate == null || annualRate == 0) {
            return 0;
        }
        return annualRate.divide(1200, 10);
    }

    /**
     * EMI = P x r x (1+r)^n / ((1+r)^n - 1)
     * 0% rate: EMI = P / n
     * Pure calculation: no SOQL, no DML.
     */
    public static Decimal calculateEmi(Decimal principal, Decimal annualRate, Integer tenureMonths) {
        if (principal == null || principal <= 0) {
            throw new EmiException('Principal must be greater than 0.');
        }
        if (annualRate == null) {
            throw new EmiException('Interest rate is required.');
        }
        if (tenureMonths == null || tenureMonths <= 0) {
            throw new EmiException('Tenure must be greater than 0.');
        }

        Decimal r = monthlyRate(annualRate);

        // 0% interest: simple division
        if (r == 0) {
            return principal.divide(tenureMonths, 2, RoundingMode.HALF_UP);
        }

        Double rate = r.doubleValue();
        Double factor = Math.pow(1 + rate, tenureMonths);
        Double emi = principal.doubleValue() * rate * factor / (factor - 1);

        return Decimal.valueOf(emi).setScale(2, RoundingMode.HALF_UP);
    }
}