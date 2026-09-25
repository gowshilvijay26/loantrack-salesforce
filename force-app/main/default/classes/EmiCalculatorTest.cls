@isTest
private class EmiCalculatorTest {

    @isTest
    static void testNormalCase() {
        Test.startTest();
        Decimal emi = EmiCalculator.calculateEmi(100000, 12, 12);
        Test.stopTest();

        System.assertEquals(8884.88, emi,
            'EMI for 100000 principal, 12% annual rate, 12 months should be 8884.88');
    }

    @isTest
    static void testZeroRate() {
        Test.startTest();
        Decimal emi = EmiCalculator.calculateEmi(120000, 0, 12);
        Test.stopTest();

        System.assertEquals(10000.00, emi,
            'EMI at 0% interest should be a simple division: principal / tenure = 10000');
    }

    @isTest
    static void testRoundingToTwoDecimals() {
        Test.startTest();
        Decimal emi = EmiCalculator.calculateEmi(500000, 9.5, 24);
        Test.stopTest();

        System.assertEquals(2, emi.scale(),
            'EMI result should always be rounded to exactly 2 decimal places');
        System.assert(emi > 0, 'EMI should be a positive amount');
    }

    @isTest
    static void testMonthlyRateConversion() {
        Test.startTest();
        Decimal rate = EmiCalculator.monthlyRate(12);
        Test.stopTest();

        System.assertEquals(0.01, rate,
            '12% annual rate should convert to 0.01 (1%) monthly rate');
    }

    @isTest
    static void testMonthlyRateZero() {
        Decimal rate = EmiCalculator.monthlyRate(0);
        System.assertEquals(0, rate, '0% annual rate should convert to 0 monthly rate');
    }

    @isTest
    static void testMonthlyRateNull() {
        Decimal rate = EmiCalculator.monthlyRate(null);
        System.assertEquals(0, rate, 'Null annual rate should be treated as 0 monthly rate');
    }

    // ---------- NEGATIVE TESTS ----------

    @isTest
    static void testNegativeCase_ZeroPrincipal() {
        Boolean exceptionThrown = false;
        try {
            EmiCalculator.calculateEmi(0, 12, 12);
        } catch (EmiCalculator.EmiException e) {
            exceptionThrown = true;
            System.assert(e.getMessage().contains('Principal'),
                'Error message should mention Principal when principal is 0');
        }
        System.assert(exceptionThrown, 'Calculating EMI with 0 principal should throw an EmiException');
    }

    @isTest
    static void testNegativeCase_NegativePrincipal() {
        Boolean exceptionThrown = false;
        try {
            EmiCalculator.calculateEmi(-5000, 12, 12);
        } catch (EmiCalculator.EmiException e) {
            exceptionThrown = true;
        }
        System.assert(exceptionThrown, 'Calculating EMI with a negative principal should throw an EmiException');
    }

    @isTest
    static void testNegativeCase_NullRate() {
        Boolean exceptionThrown = false;
        try {
            EmiCalculator.calculateEmi(100000, null, 12);
        } catch (EmiCalculator.EmiException e) {
            exceptionThrown = true;
            System.assert(e.getMessage().contains('rate'),
                'Error message should mention rate when interest rate is null');
        }
        System.assert(exceptionThrown, 'Calculating EMI with a null interest rate should throw an EmiException');
    }

    @isTest
    static void testNegativeCase_ZeroTenure() {
        Boolean exceptionThrown = false;
        try {
            EmiCalculator.calculateEmi(100000, 12, 0);
        } catch (EmiCalculator.EmiException e) {
            exceptionThrown = true;
        }
        System.assert(exceptionThrown, 'Calculating EMI with 0 tenure should throw an EmiException');
    }

    @isTest
    static void testNegativeCase_NullTenure() {
        Boolean exceptionThrown = false;
        try {
            EmiCalculator.calculateEmi(100000, 12, null);
        } catch (EmiCalculator.EmiException e) {
            exceptionThrown = true;
        }
        System.assert(exceptionThrown, 'Calculating EMI with a null tenure should throw an EmiException');
    }
}