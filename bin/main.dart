import 'package:oil_data_crawler/opinet_api_getter.dart';

Future<void> main(List<String> args) async {
  //args = ['getRecentData'];
  if (args.isNotEmpty) {
    String functionName = args[0];
    switch (functionName) {
      case 'getTodayData':
        await getSigunCode();
        break;
      case 'getRecentData':
        // setPriceFromWeekPrice();
        await getAvgSidoPrice();
        await getAvgSigunPrice();
        break;
      default:
        print('Invalid function name');
    }
  } else {
    print('No function name provided');
  }
}
