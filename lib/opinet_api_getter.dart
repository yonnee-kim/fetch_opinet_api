import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

String? opinetApiKey = Platform.environment['OPINET_API_KEY'];
String url = '';
Map<String, String> oilCode = {
  '휘발유': 'B027',
  '경유': 'D047',
  '고급휘발유': 'B034',
  '실내등유': 'C004',
  '자동차부탄': 'K015',
};

// Call 제한 수 : 1,500(call/일)
/* 
가격 업테이트 시각 
현재 판매가격 : 1시, 2시, 9시, 12시, 16시, 19시
일일 평균가격 : 24시
주간 평균가격 : 금요일 10시
요소수 판매가격 : 7시, 13시, 18시, 24시
*/
// 사용가능 api 총 19개

// var avgAllPrice; // 전국 주유소 현재 평균 가격
// var avgSidoPrice; // 시도별 주유소 평균 가격
// var avgSigunPrice; // 시군구별 주유소 평균가격
// var avgRecentPrice; // 최근 7일간 전국 일일 평균가격
// var pollAvgRecentPrice; // 최근 7일간 전국 일일 상표별 평균가격
// var areaAvgRecentPrice; // 최근 7일간 전국 일일 지역별 평균가격
// var avgLastWeek; // 최근 1주의 주간 평균유가(전국/시도별)
// var lowTop20; // 지역별 최저가 주유소(TOP20)
// var aroundAll; // 반경내 주유소
// var detailById; // 주유소 상세정보(ID)
// var searchByName; // 상호로 주유소 검색
// var taxfreeAvgAllPrice; // 전국 면세유 주유소 평균가격
// var taxfreeAvgSidoPrice; // 시도별 면세유 주유소 평균가격
// var taxfreeAvgSigunPrice; // 시군구별 면세유 주유소 평균가격
// var taxfreeAvgRecentPrice; // 최근 7일간 전국 일일 면세유 평균가격
// var taxPollAvgRecentPrice; // 최근 7일간 전국 일일 상표별 면세유 평균가격
// var taxfreeLowTop20; // 지역별 최저가 면세유 주유소(TOP20)
// var ureaPrice; // 요소수 주유소 판매가격(지역별)
// var areaCode; // 지역코드

Future<void> getAvgAllPrice() async {
  url = 'http://www.opinet.co.kr/api/avgAllPrice.do?out=json&code=$opinetApiKey';
  var response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    var data = json.decode(utf8.decode(response.bodyBytes));
    var oilList = data['RESULT']['OIL'];

    // 각 유종의 이름과 가격을 출력합니다.
    for (var oil in oilList) {
      String productName = oil['PRODNM'];
      double price = double.parse(oil['PRICE']);
      print('$productName: $price 원');
    }
  } else {
    print("getAvgAllPrice / response statusCode : ${response.statusCode}");
  }
}

Future<void> getAvgWeekPriceSido() async {
  // SIGUN에서 AREA_CD 추가
  var sidoSigunCode = json.decode(await File('json/sido_sigun_code.json').readAsString());
  List sidoCodeList = [];
  // 모든 시군코드 반환
  for (var sido in sidoSigunCode['SIDO']) {
    sidoCodeList.add(sido['AREA_CD']);
  }
  print('sigunCodeList(시군 코드 리스트)의 길이는 : ${sidoCodeList.length}');

  // 시군별 7일간 평균가격 조회 및 저장
  List areaAvgWeekPrice = [];
  for (String sidoCode in sidoCodeList) {
    url = 'http://www.opinet.co.kr/api/areaAvgRecentPrice.do?out=json&code=$opinetApiKey&area=$sidoCode';

    // 재시도 로직
    int retries = 3;
    bool success = false;
    while (retries > 0 && !success) {
      try {
        var response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          var data = json.decode(response.body);
          areaAvgWeekPrice.addAll(data['RESULT']['OIL']);
          print('${data['RESULT']['OIL'][0]['AREA_NM']} 7일간 평균가격 조회 완료');
          success = true; // 성공적으로 데이터를 가져왔으므로 루프 종료
        } else {}
      } catch (e) {
        print('getAreaAvgWeekPrice 에러 발생 e : $e');
      }
      if (!success) {
        retries--; // 재시도 횟수 감소
        print('getAreaAvgWeekPrice 재시도 중... 남은 횟수: $retries');
      }
      await Future.delayed(Duration(milliseconds: 100)); // 0.2초 대기
    }
  }
  File('json/avg_week_price_sido.json').writeAsString(json.encode(areaAvgWeekPrice));
}

Future<void> getAvgWeekPriceSigun() async {
  // SIGUN에서 AREA_CD 추가
  var sidoSigunCode = json.decode(await File('json/sido_sigun_code.json').readAsString());
  List sigunCodeList = [];
  // 모든 시군코드 반환
  for (var sido in sidoSigunCode['SIDO']) {
    for (var sigun in sido['SIGUN']) {
      sigunCodeList.add(sigun['AREA_CD']);
    }
  }
  print('sigunCodeList(시군 코드 리스트)의 길이는 : ${sigunCodeList.length}');

  // 시군별 7일간 평균가격 조회 및 저장
  List areaAvgWeekPrice = [];
  for (String sigunCode in sigunCodeList) {
    url = 'http://www.opinet.co.kr/api/areaAvgRecentPrice.do?out=json&code=$opinetApiKey&area=$sigunCode';

    // 재시도 로직
    int retries = 3;
    bool success = false;
    while (retries > 0 && !success) {
      try {
        var response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          var data = json.decode(response.body);
          areaAvgWeekPrice.addAll(data['RESULT']['OIL']);
          print('${data['RESULT']['OIL'][0]['AREA_NM']} 7일간 평균가격 조회 완료');
          success = true; // 성공적으로 데이터를 가져왔으므로 루프 종료
        } else {}
      } catch (e) {
        print('getAreaAvgWeekPrice 에러 발생 e : $e');
      }
      if (!success) {
        retries--; // 재시도 횟수 감소
        print('getAreaAvgWeekPrice 재시도 중... 남은 횟수: $retries');
      }
      await Future.delayed(Duration(milliseconds: 100)); // 0.2초 대기
    }
  }
  File('json/avg_week_price_sigun.json').writeAsString(json.encode(areaAvgWeekPrice));
}

Future<void> getAvgSigunPrice() async {
  var sidoSigunCode = json.decode(await File('json/sido_sigun_code.json').readAsString());
  List sidoCodeList = (sidoSigunCode['SIDO'] as List).map((e) => e["AREA_CD"]).toList(); //모든 시도코드 반환
  List sigunEntriesList = [];
  File file = File('json/avg_sigun_price.json');
  File smallFile = File('json/avg_sigun_price_small.json');
  List existingData = jsonDecode(await file.readAsString());
  bool isSame = true;
  int tryCount = 10;
  int tryCount2 = 10;
  int delayMinutes = 1;

  // 1
  // API 데이터 업데이트 확인
  while (isSame) {
    url = 'http://www.opinet.co.kr/api/avgSigunPrice.do?out=json&sido=01&code=$opinetApiKey';
    // 재시도 로직 (네트워크 연결 확인)
    dynamic data;
    bool isConnected = false;
    while (!isConnected) {
      try {
        var response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          data = json.decode(response.body);
          print('${data['RESULT']['OIL'][0]['SIGUNNM']} 평균 가격 조회 완료.');
          isConnected = true; // 성공적으로 데이터를 가져왔으므로 루프 종료
        } else if (tryCount > 0) {
          tryCount--;
          // 요청 실패 시 URL과 body 출력
          print('response 요청 실패: ${response.statusCode}');
          print('요청한 URL: $url');
          print('재시도 중...남은 재시도 횟수 : $tryCount 회');
          await Future.delayed(Duration(milliseconds: 500));
        } else if (tryCount <= 0) {
          print('getAvgSigunPrice 실패. 함수 종료.');
          return;
        }
      } catch (e) {
        tryCount--;
        print('getAvgSigunPrice 에러 발생 error : $e');
        await Future.delayed(Duration(milliseconds: 500));
        if (tryCount <= 0) {
          print('getAvgSigunPrice 실패. 함수 종료.');
          return;
        }
      }
    }
    // 중복 확인 로직 (API 업데이트 확인)
    if (existingData.isEmpty || jsonEncode(data['RESULT']['OIL']) != jsonEncode(existingData.last["DATA"][0]["DATA"])) {
      isSame = false;
      print('시군구별 평균가격 업데이트 확인 완료');
    } else {
      tryCount2--;
      if (tryCount2 > 2) {
        print('getAvgSigunPrice()의 반환값 기존과 같음. $delayMinutes분 후 다시 시도. 남은 시도횟수 : $tryCount2');
        await Future.delayed(Duration(minutes: delayMinutes));
      } else if (tryCount2 <= 2 && tryCount2 > 0) {
        print('getAvgSigunPrice()의 반환값 기존과 같음. ${delayMinutes * 5}분 후 다시 시도. 남은 시도횟수 : $tryCount2');
        await Future.delayed(Duration(minutes: delayMinutes * 5));
      } else if (tryCount2 == 0) {
        print('API 업데이트 확인 실패. 함수 종료.');
        return;
      }
    }
  }
  tryCount = 10; // 재시도 횟수 초기화
  // 2
  // 모든 시/도 현재 평균 가격 조회
  for (int i = 0; i < sidoCodeList.length; i++) {
    url = 'http://www.opinet.co.kr/api/avgSigunPrice.do?out=json&sido=${sidoCodeList[i]}&code=$opinetApiKey';
    // 재시도 로직 (네트워크 연결 확인)
    bool isConnected = false;
    while (!isConnected) {
      try {
        var response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          var data = json.decode(response.body);
          Map sigunEntries = {'SIDOCD': sidoCodeList[i], 'DATA': data['RESULT']['OIL']};
          sigunEntriesList.add(sigunEntries);
          print('${sidoSigunCode['SIDO'][i]['AREA_NM']} 시군구 평균 가격 조회 완료.');
          isConnected = true; // 성공적으로 데이터를 가져왔으므로 루프 종료
        } else if (tryCount > 0) {
          tryCount--;
          // 요청 실패 시 URL과 body 출력
          print('response 요청 실패: ${response.statusCode}');
          print('요청한 URL: $url');
          print('요청한 sidocode : ${sidoCodeList[i]} / ${sidoSigunCode['SIDO'][i]['AREA_NM']}');
          print('재시도 중... 남은 재시도 횟수 : $tryCount 회');
          await Future.delayed(Duration(milliseconds: 500));
        } else if (tryCount <= 0) {
          print('getAvgSigunPrice 실패. 함수 종료.');
          return;
        }
      } catch (e) {
        tryCount--;
        print('getAvgSigunPrice 에러 발생 error : $e');
        await Future.delayed(Duration(milliseconds: 500));
        if (tryCount <= 0) {
          print('getAvgSigunPrice 실패. 함수 종료.');
          return;
        }
      }
    }
  }
  // 한국시간으로 현재시간 가져오기
  print('기존 avgSigunPrice 길이는 ${existingData.length}');
  DateTime nowKST = DateTime.now().toUtc().add(Duration(hours: 9));
  Map sidoEntries = {'DATE': nowKST.toString(), 'DATA': sigunEntriesList};
  List avgSigunPrice = existingData..add(sidoEntries);
  await file.writeAsString(json.encode(avgSigunPrice));
  if (avgSigunPrice.length > 150) {
    List smallAvgSigunPrice = avgSigunPrice.sublist(avgSigunPrice.length - 150, avgSigunPrice.length);
    await smallFile.writeAsString(json.encode(smallAvgSigunPrice));
  }
  print('$nowKST / 시군구별 현재 평균가격 조회 및 저장 완료');
  print('저장 후 avgSigunPrice 길이는 ${avgSigunPrice.length}');
}

Future<void> getAvgSidoPrice() async {
  List entriesList = [];
  File file = File('json/avg_sido_price.json');
  File smallFile = File('json/avg_sido_price_small.json');
  List existingData = jsonDecode(await file.readAsString());
  bool isSame = true;
  int tryCount = 10;
  int tryCount2 = 10;
  int delayMinutes = 1;
  dynamic data;

  // 1
  // API 데이터 업데이트 확인
  while (isSame) {
    url = 'http://www.opinet.co.kr/api/avgSidoPrice.do?out=json&code=$opinetApiKey';
    // 재시도 로직 (네트워크 연결 확인)

    bool isConnected = false;
    while (!isConnected) {
      try {
        var response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          data = json.decode(response.body);
          print('시도별 평균 가격 조회 완료.');
          isConnected = true; // 성공적으로 데이터를 가져왔으므로 루프 종료
        } else if (tryCount > 0) {
          tryCount--;
          // 요청 실패 시 URL과 body 출력
          print('response 요청 실패: ${response.statusCode}');
          print('요청한 URL: $url');
          print('재시도 중... 남은 재시도 횟수 : $tryCount 회');
          await Future.delayed(Duration(milliseconds: 500));
        } else if (tryCount <= 0) {
          print('getAvgSidoPrice 실패. 함수 종료.');
          return;
        }
      } catch (e) {
        tryCount--;
        print('getAvgSidoPrice 에러 발생 error : $e');
        await Future.delayed(Duration(milliseconds: 500));
        if (tryCount <= 0) {
          print('getAvgSidoPrice 실패. 함수 종료.');
          return;
        }
      }
    }
    // 중복 확인 로직 (API 업데이트 확인)
    if (existingData.isEmpty || jsonEncode(data['RESULT']['OIL']) != jsonEncode(existingData.last["DATA"])) {
      isSame = false;
      print('시도별 평균가격 업데이트 확인 완료');
    } else {
      tryCount2--;
      if (tryCount2 > 2) {
        print('getAvgSidoPrice()의 반환값 기존과 같음. $delayMinutes분 후 다시 시도. 남은 시도횟수 : $tryCount2');
        print(jsonEncode(data['RESULT']['OIL']));
        await Future.delayed(Duration(minutes: delayMinutes));
      } else if (tryCount2 <= 2 && tryCount2 > 0) {
        print('getAvgSidoPrice()의 반환값 기존과 같음. ${delayMinutes * 5}분 후 다시 시도. 남은 시도횟수 : $tryCount2');
        await Future.delayed(Duration(minutes: delayMinutes * 5));
      } else if (tryCount2 == 0) {
        print('API 업데이트 확인 실패. 함수 종료.');
        return;
      }
    }
  }
  entriesList = data['RESULT']['OIL'];
  // 한국시간으로 현재시간 가져오기
  print('기존 avgSidoPrice 길이는 ${existingData.length}');
  DateTime nowKST = DateTime.now().toUtc().add(Duration(hours: 9));
  Map sidoEntries = {'DATE': nowKST.toString(), 'DATA': entriesList};
  List avgSidoPrice = existingData..add(sidoEntries);
  await file.writeAsString(json.encode(avgSidoPrice));
  if (avgSidoPrice.length > 150) {
    List smallAvgSidoPrice = avgSidoPrice.sublist(avgSidoPrice.length - 150, avgSidoPrice.length);
    await smallFile.writeAsString(json.encode(smallAvgSidoPrice));
  }
  print('$nowKST / 시도별 현재 평균가격 조회 및 저장 완료');
  print('저장 후 avgSidoPrice 길이는 ${avgSidoPrice.length}');
}

Future<void> getSigunCode() async {
  // getAreaCode
  File file = File('json/sido_sigun_code.json');
  url = 'http://www.opinet.co.kr/api/areaCode.do?out=json&code=$opinetApiKey';
  var data;
  bool isConnect = false;
  int tryCount = 5;
  int delaySeconds = 1;

  // 시도 리스트 가져오기
  while (!isConnect) {
    var response = await http.get(Uri.parse(url));
    try {
      if (response.statusCode == 200) {
        print('getSigunCode url 연결 성공');
        data = json.decode(response.body);
        isConnect = true;
      } else if (tryCount > 0) {
        tryCount--;
        print('getSigunCode url 연결오류 $delaySeconds초 후 재시도. 남은 재시도 횟수 : $tryCount \nresponse statusCode : ${response.statusCode}');
        await Future.delayed(Duration(seconds: delaySeconds));
      } else if (tryCount <= 0) {
        print("getSigunCode 종료. url 연결오류 response statusCode : ${response.statusCode}");
        return;
      }
    } catch (e) {
      tryCount--;
      print('getSigunCode url 연결오류 $delaySeconds초 후 재시도. 남은 재시도 횟수 : $tryCount \nerror : $e');
      await Future.delayed(Duration(seconds: delaySeconds));
      if (tryCount <= 0) {
        print('getSigunCode 실패. 함수 종료.');
        return;
      }
    }
  }
  // 시군구 리스트 가져오기
  if (data['RESULT']['OIL'] != null) {
    List<Map<String, dynamic>> sidoList = List<Map<String, dynamic>>.from(data['RESULT']['OIL']);
    for (int i = 0; i < sidoList.length; i++) {
      isConnect = false;
      tryCount = 5;
      String areaName = sidoList[i]["AREA_NM"];
      String areaCode = sidoList[i]["AREA_CD"];
      print('$areaName areaCode : $areaCode');
      url = 'http://www.opinet.co.kr/api/areaCode.do?out=json&code=$opinetApiKey&area=$areaCode';
      while (!isConnect) {
        try {
          var response = await http.get(Uri.parse(url));
          if (response.statusCode == 200) {
            var sigunCodeData = json.decode(response.body);
            Map<String, List<Map>> sidoSigunMap = <String, List<Map>>{'SIGUN': List<Map>.from(sigunCodeData['RESULT']['OIL'])};
            sidoList[i].addEntries(sidoSigunMap.entries);
            isConnect = true;
            print('$areaName 시군코드 가져오기 완료');
          } else if (tryCount > 0) {
            tryCount--;
            print('getSigunCode $areaName url 연결오류 $delaySeconds초 후 재시도. 남은 재시도 횟수 : $tryCount \nresponse statusCode : ${response.statusCode}');
            await Future.delayed(Duration(seconds: delaySeconds));
          } else if (tryCount <= 0) {
            print("getSigunCode 종료. url 연결오류 response statusCode : ${response.statusCode}");
            return;
          }
        } catch (e) {
          tryCount--;
          print('getSigunCode $areaName url 연결오류 $delaySeconds초 후 재시도. 남은 재시도 횟수 : $tryCount \nerror : $e');
          await Future.delayed(Duration(seconds: delaySeconds));
          if (tryCount <= 0) {
            print('getSigunCode 실패. 함수 종료.');
            return;
          }
        }
      }
    }
    Map sidoSigunCode = {"SIDO": sidoList};
    String exsitingFile = await file.readAsString();
    if (jsonEncode(sidoSigunCode) != exsitingFile) {
      print('시도 시군 코드 변경사항 업데이트 완료.');
      await file.writeAsString(json.encode(sidoSigunCode));
    } else {
      print('시도 시군 코드 변경사항 없음.');
    }
  } else {
    print('''에러발생 : getSigunCode data['RESULT']['OIL'] 값이 null 임.''');
    print("data['RESULT']['OIL'] : ${data['RESULT']['OIL']}");
  }
}

void setPriceFromWeekPrice() async {
  var sidoSigunCode = json.decode(await File('json/sido_sigun_code.json').readAsString());
  List sidoCodeList = sidoSigunCode['SIDO'].map((e) => e['AREA_CD']).toList();
  print(sidoCodeList);
  var weekPriceSigun = json.decode(await File('json/avg_week_price_sigun.json').readAsString());
  var weekPriceSido = json.decode(await File('json/avg_week_price_sido.json').readAsString());
  var avgSigunPrice = json.decode(await File('json/old_avg_sigun_price.json').readAsString());
  var avgSidoPrice = json.decode(await File('json/old_avg_sido_price.json').readAsString());
  var newSigunPrice = [];
  var newSidoPrice = [];
  List dateList = [];
  // set dateList
  for (var e in weekPriceSido) {
    dateList.add(e['DATE']);
  }
  // weekPrice key 이름 변경
  for (var e in weekPriceSido) {
    e['SIDOCD'] = e['AREA_CD'];
    e.remove('AREA_CD');
    e['SIDONM'] = e['AREA_NM'];
    e.remove('AREA_NM');
  }
  for (var e in weekPriceSigun) {
    e['SIGUNCD'] = e['AREA_CD'];
    e.remove('AREA_CD');
    e['SIGUNNM'] = e['AREA_NM'];
    e.remove('AREA_NM');
  }
  dateList = dateList.toSet().toList();
  print('dateList = $dateList');
  for (var date in dateList) {
    List dataList = [];
    for (var e in weekPriceSido) {
      if (e['DATE'] == date) {
        dataList.add(e);
      }
    }
    newSidoPrice.add({'DATE': dateTimeParser(date), 'DATA': dataList});
  }
  newSidoPrice.addAll(avgSidoPrice);
  newSidoPrice.sort((a, b) => a['DATE'].compareTo(b['DATE']));
  List asdff = newSidoPrice.map((e) => e['DATE']).toList();
  for (var element in asdff) {
    print(element);
  }
  File('json/new_avg_week_price_sido.json').writeAsString(json.encode(newSidoPrice));

  for (var date in dateList) {
    List dataList = [];
    for (var sido in sidoCodeList) {
      List sidoDataList = [];
      for (var e in weekPriceSigun) {
        if (e['DATE'] == date && e['SIGUNCD'].substring(0, 2) == sido) {
          sidoDataList.add(e);
        }
      }
      dataList.add({'SIDOCD': sido, 'DATA': sidoDataList});
    }
    newSigunPrice.add({'DATE': dateTimeParser(date), 'DATA': dataList});
  }
  newSigunPrice.addAll(avgSigunPrice);
  newSigunPrice.sort((a, b) => a['DATE'].compareTo(b['DATE']));
  //print('newSigunPrice = $newSigunPrice');
  print('\ndate 리스트 : ${newSigunPrice.map((e) => e['DATE']).toList()}');
  List asdf = newSigunPrice.map((e) => e['DATE']).toList();
  for (var element in asdf) {
    print(element);
  }
  File('json/new_avg_week_price_sigun.json').writeAsString(json.encode(newSigunPrice));
}

String dateTimeParser(String dateString) {
  String formattedDateString = "${dateString.substring(0, 4)}-${dateString.substring(4, 6)}-${dateString.substring(6, 8)}";
  DateTime dateTime = DateTime.parse(formattedDateString);
  return dateTime.toString();
}
