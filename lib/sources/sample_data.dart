import '../engine/ingest.dart';
import '../model/transaction.dart';

/// Realistic bank SMS / UPI notifications for the demo and web preview.
/// They go through the same parser and detectors as real messages.
List<RawMessage> sampleMessages(DateTime now) {
  var n = 0;
  RawMessage sms(int daysAgo, int hour, int minute, String sender, String body) => RawMessage(
        source: Source.sample,
        sourceId: 'sample-${n++}',
        sender: sender,
        body: body,
        at: DateTime(now.year, now.month, now.day, hour, minute)
            .subtract(Duration(days: daysAgo)),
      );

  return [
    sms(0, 13, 5, 'VM-HDFCBK', 'Rs.450.00 debited from A/c XX4821 on today to VPA swiggy@icici UPI Ref 528193004411. Not you? Call 18002586161'),
    sms(0, 9, 40, 'AD-ICICIB', 'INR 286.40 spent on ICICI Bank Card XX9034 at UBER INDIA on today. Avl Lmt: INR 1,12,400.'),
    sms(1, 20, 15, 'VM-HDFCBK', 'Rs.2000.00 debited from A/c XX4821 to VPA 9876543210@ybl (UPI/P2A/528193004520/RAHUL SHARMA). Ref 528193004520'),
    sms(1, 19, 2, 'VM-HDFCBK', 'Rs.1120.00 debited from A/c XX4821 to VPA blinkit.payu@hdfcbank UPI Ref 528193004522'),
    // Self transfer: HDFC → SBI, both your accounts.
    sms(2, 10, 0, 'VM-HDFCBK', 'Rs.15000.00 debited from A/c XX4821 to A/c XX7712 IMPS Ref 628193004001'),
    sms(2, 10, 1, 'JD-SBIINB', 'Your A/c XX7712 credited by Rs.15,000.00 on IMPS from A/c XX4821. Ref 628193004001'),
    sms(3, 18, 30, 'AD-ICICIB', 'INR 3,499.00 spent on ICICI Bank Card XX9034 at MYNTRA DESIGNS PVT LTD on date.'),
    sms(4, 8, 10, 'VM-HDFCBK', 'Rs.649.00 debited from A/c XX4821 to VPA netflix.upi@icici for autopay. UPI Ref 528193004601'),
    sms(5, 21, 45, 'VM-HDFCBK', 'Rs.800.00 debited from A/c XX4821 to VPA meera.iyer@okaxis UPI Ref 528193004700'),
    sms(6, 12, 0, 'JD-SBIINB', 'Rs 2000 withdrawn at SBI ATM from A/c XX7712 on date. Avl Bal Rs 31,220.'),
    sms(7, 9, 0, 'VM-HDFCBK', 'Your A/c XX4821 is credited with INR 85,000.00 by NEFT from ACME TECH PVT LTD. Ref N2810040017'),
    sms(7, 11, 20, 'VM-HDFCBK', 'Rs.12500.00 debited from A/c XX4821 towards your Credit Card bill payment XX9034. Ref 628193004200'),
    sms(8, 14, 5, 'VM-HDFCBK', 'Rs.320.00 debited from A/c XX4821 to VPA paytmqr28100505@paytm UPI Ref 528193004810'),
    sms(9, 19, 30, 'AD-ICICIB', 'INR 1,240.00 spent on ICICI Bank Card XX9034 at BOOKMYSHOW on date.'),
    sms(9, 7, 0, 'AD-ICICIB', 'INR 1,500.00 spent on ICICI Bank Card XX9034 at CULTFIT on date.'),
    sms(10, 7, 50, 'VM-HDFCBK', 'Rs.599.00 debited from A/c XX4821 to VPA airtel@icici UPI Ref 528193004900 for Airtel recharge'),
    sms(11, 16, 0, 'VM-HDFCBK', 'Rs.450.00 credited to A/c XX4821 from VPA aarav.mehta@okaxis UPI Ref 528193005000'),
    sms(12, 13, 0, 'VM-HDFCBK', 'Rs.5000.00 debited from A/c XX4821 to VPA savings.me@okicici - Self Transfer. Ref 528193005100'),
    sms(13, 20, 0, 'VM-HDFCBK', '482913 is your OTP for payment of Rs 1,999 at AMAZON. Do not share.'),
    sms(14, 10, 30, 'AD-ICICIB', 'INR 2,350.00 spent on ICICI Bank Card XX9034 at APOLLO PHARMACY on date.'),
    sms(16, 12, 45, 'VM-HDFCBK', 'Rs.18000.00 debited from A/c XX4821 to VPA ramesh.kumar@oksbi UPI Ref 528193005300'),
    // Earlier months — repeats (rent, Netflix, gym) and a spread for trends.
    for (final m in [1, 2, 3, 4, 5]) ...[
      sms(16 + 30 * m, 12, 45, 'VM-HDFCBK', 'Rs.18000.00 debited from A/c XX4821 to VPA ramesh.kumar@oksbi UPI Ref 52819300${m}301'),
      sms(4 + 30 * m, 8, 10, 'VM-HDFCBK', 'Rs.649.00 debited from A/c XX4821 to VPA netflix.upi@icici. UPI Ref 52819300${m}601'),
      sms(9 + 30 * m, 7, 0, 'AD-ICICIB', 'INR 1,500.00 spent on ICICI Bank Card XX9034 at CULTFIT on date.'),
      sms(6 + 30 * m, 13, 20, 'VM-HDFCBK', 'Rs.${380 + m * 45}.00 debited from A/c XX4821 to VPA swiggy@icici UPI Ref 52819300${m}801'),
      sms(12 + 30 * m, 19, 0, 'VM-HDFCBK', 'Rs.${900 + m * 310}.00 debited from A/c XX4821 to VPA bigbasket@hdfcbank UPI Ref 52819300${m}901'),
      sms(21 + 30 * m, 18, 30, 'AD-ICICIB', 'INR ${(m.isEven ? 2400 : 5600)}.00 spent on ICICI Bank Card XX9034 at AMAZON on date.'),
      sms(25 + 30 * m, 9, 15, 'AD-ICICIB', 'INR ${240 + m * 20}.00 spent on ICICI Bank Card XX9034 at UBER INDIA on date.'),
    ],
  ];
}
