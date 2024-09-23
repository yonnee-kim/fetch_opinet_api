import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:webdriver/async_io.dart';

int crawlCount = 0;

Future<void> getCrawlingData() async {
  final file = File('json/oil_price_data.json');
  List existingFile = jsonDecode(await file.readAsString());
  List<Map<String, String>> oilData = [];
  List<Map<String, String>> smallOilData = [];
  int totalPages = 1;
  int tblCount = 0;
  bool isSame = true;
  bool isConected = false;
  int tryCount = 100;
  int delaySeconds = 10;

  String url = "https://www.consumer.go.kr/ajaxPriceInfo/ajaxSelectPriceInfoOilList.do";
  final body = {
    "sidoCd": "",
    "sigunCd": "",
    "opinetPollDivCd": "",
    "opinetOilStationNm": "",
    "page": '1',
    "row": '10',
    "sortType": "",
    "la": "",
    "lo": "",
  };
  final headers = {
    "Accept":
        "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7",
    "Accept-Encoding": "gzip, deflate, br, zstd",
    "Accept-Language": "ko",
    "Connection": "keep-alive",
    "Cookie": "JSESSIONID=2JNzeXt9O3nEoOtbfX7lVlkK.ftc21", // 필요 시 세션 ID 추가
    "Host": "www.consumer.go.kr",
    "User-Agent":
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36 Edg/127.0.0.0",
    "Sec-Fetch-Mode": "navigate",
    "Sec-Fetch-Site": "none",
    "Sec-Fetch-User": "?1",
    "Upgrade-Insecure-Requests": "1",
  };

  // 1
  while (isSame) {
    // url 연결
    while (!isConected) {
      try {
        var response = await http.post(Uri.parse(url), headers: headers, body: body);
        if (response.statusCode == 200) {
          isConected = true;
          final document = html_parser.parse(response.body);
          final rows = document.querySelectorAll('.tbl.list.gray.tbl_word.rwd table tbody tr');
          for (var row in rows) {
            final columns = row.querySelectorAll('td');
            if (columns.isNotEmpty) {
              final data = {
                '상표': columns[0].text.trim(),
                '주유소': columns[1].text.trim(),
                '주소': columns[2].text.trim(),
                '품질인증': columns[3].text.trim(),
                '기준일자': columns[4].text.trim(),
                '휘발유가격': columns[5].text.trim(),
                '경유가격': columns[6].text.trim(),
                '고급휘발유가격': columns[7].text.trim(),
                'LPG가격': columns[8].text.trim(),
                '위치': columns[9].querySelector('a')?.attributes['href'] ?? '',
              };
              smallOilData.add(data);
            }
          }
        } else if (tryCount > 0) {
          tryCount--;
          // 요청 실패 시 URL과 body 출력
          print('response 요청 실패: ${response.statusCode}');
          print('요청한 URL: $url');
          print('요청 본문: $body');
          print('재시도 중... 남은 재시도 횟수 : $tryCount 회');
          await Future.delayed(Duration(milliseconds: 500));
        } else if (tryCount <= 0) {
          print('getCrawlingData 실패. 함수 종료.');
          return;
        }
        print('smallOilData.length : ${smallOilData.length}');
      } catch (e) {
        tryCount--;
        print('error 발생 : $e');
        await Future.delayed(Duration(milliseconds: 500));
        if (tryCount <= 0) {
          print('getCrawlingData 실패. 함수 종료.');
          return;
        }
      }
    }
    // API 업데이트 확인
    if (isSame && (existingFile.isEmpty || smallOilData.toString() != existingFile.sublist(0, 10).toString())) {
      isSame = false;
      print('전국 주유소 현재가격 업데이트 확인 완료');
    } else if (isSame) {
      tryCount--;
      smallOilData = [];
      if (tryCount > 10) {
        print('getCrawlingData()의 반환값 기존과 같음. $delaySeconds 초 후 다시 시도. 남은 시도횟수 : $tryCount');
        await Future.delayed(Duration(seconds: delaySeconds));
      } else if (tryCount <= 10 && tryCount > 0) {
        print('getCrawlingData()의 반환값 기존과 같음. 1분 후 다시 시도. 남은 시도횟수 : $tryCount!!!');
        await Future.delayed(Duration(minutes: 1));
      } else if (tryCount == 0) {
        print('크롤링데이터 업데이트 확인 실패. 함수 종료.');
        return;
      }
    }
  }
  // 2
  body['row'] = '5000'; // 5000건씩 검색
  tryCount = 10; // 네트워크 연결 재시도 횟수
  isConected = false; //isConnected 초기화
  // 총 페이지 수 추출
  while (!isConected) {
    try {
      var response = await http.post(Uri.parse(url), headers: headers, body: body);
      if (response.statusCode == 200) {
        isConected = true;
        final document = html_parser.parse(response.body);

        // 총 주유소 개수를 추출하는 로직
        if (document.querySelector('.tbl_list_count') != null) {
          String stringTblCount = document.querySelector('.tbl_list_count')!.text;
          tblCount = int.parse(stringTblCount.replaceAll(RegExp(r'[^0-9]'), ''));
        }
        print('tblCount 총 주유소 개수 : $tblCount');

        // 총 페이지 수를 추출하는 로직
        final pagination = document.querySelector('.galleryPagination');
        if (pagination != null) {
          final lastPageLink = pagination.querySelector('.btn_last')?.attributes['href'];
          if (lastPageLink != null) {
            // 'pageChanged('1132','10')' 형식에서 1132를 추출
            final regex = RegExp(r"pageChanged\('(\d+)',");
            final match = regex.firstMatch(lastPageLink);
            if (match != null) {
              totalPages = int.parse(match.group(1)!);
              print('totalPages : $totalPages');
            }
          }
        }
      } else if (tryCount > 0) {
        tryCount--;
        // 요청 실패 시 URL과 body 출력
        print('response 요청 실패: ${response.statusCode}');
        print('요청한 URL: $url');
        print('요청 본문: $body');
        print('재시도 중... 남은 재시도 횟수 : $tryCount 회');
        await Future.delayed(Duration(milliseconds: 500));
      } else if (tryCount <= 0) {
        print('getCrawlingData 실패. 함수 종료.');
        return;
      }
    } catch (e) {
      tryCount--;
      print('error 발생 : $e');
      await Future.delayed(Duration(milliseconds: 500));
      if (tryCount <= 0) {
        print('getCrawlingData 실패. 함수 종료.');
        return;
      }
    }
  }
  // 3
  // 모든 페이지를 순회하며 정보 가져오기
  for (int currentPage = 1; currentPage <= totalPages; currentPage++) {
    isConected = false;
    tryCount = 10;
    body['page'] = currentPage.toString();

    while (!isConected) {
      try {
        var response = await http.post(Uri.parse(url), headers: headers, body: body);
        if (response.statusCode == 200) {
          isConected = true;
          final document = html_parser.parse(response.body);
          final rows = document.querySelectorAll('.tbl.list.gray.tbl_word.rwd table tbody tr');

          for (var row in rows) {
            final columns = row.querySelectorAll('td');
            if (columns.isNotEmpty) {
              final data = {
                '상표': columns[0].text.trim(),
                '주유소': columns[1].text.trim(),
                '주소': columns[2].text.trim(),
                '품질인증': columns[3].text.trim(),
                '기준일자': columns[4].text.trim(),
                '휘발유가격': columns[5].text.trim(),
                '경유가격': columns[6].text.trim(),
                '고급휘발유가격': columns[7].text.trim(),
                'LPG가격': columns[8].text.trim(),
                '위치': columns[9].querySelector('a')?.attributes['href'] ?? '',
              };
              oilData.add(data);
            }
          }
          print('$currentPage/$totalPages 번째 페이지 저장 완료');
        } else if (tryCount > 0) {
          // 요청 실패 시 URL과 body 출력
          print('response 요청 실패: ${response.statusCode}');
          print('요청한 URL: $url');
          print('요청 본문: $body');
          print('재시도 중... 남은 재시도 횟수 : $tryCount 회');
          await Future.delayed(Duration(milliseconds: 500));
        } else if (tryCount <= 0) {
          print('getCrawlingData 실패. 함수 종료.');
          return;
        }
      } catch (e) {
        tryCount--;
        print('error 발생 : $e');
        await Future.delayed(Duration(milliseconds: 500));
        if (tryCount <= 0) {
          print('getCrawlingData 실패. 함수 종료.');
          return;
        }
      }
    }
  }
  print('oilData 총 길이는 : ${oilData.length}');
  // 중복 제거
  for (int i = 0; i < oilData.length - 1; i++) {
    if (jsonEncode(oilData[i]) == jsonEncode(oilData[i + 1])) {
      oilData.removeAt(i);
      i--;
    }
  }
  print('중복 제거한 oilData 총 길이는 : ${oilData.length}');
  await saveDataToFile(oilData);
}

Future<void> saveDataToFile(List<Map<String, String>> data) async {
  final file = File('json/oil_price_data.json');

  await file.writeAsString(jsonEncode(data));
  print('Recent oil price data has been saved');
}

Future<void> func() async {
  final file = File('oil_price_data.json');
  List<Map<String, dynamic>> existingData = [];
  List<String> stationName = [];
  List<String> overlapName = [];

  final contents = await file.readAsString();
  if (contents.isNotEmpty) {
    existingData = List<Map<String, dynamic>>.from(jsonDecode(contents));
    for (Map<String, dynamic> data in existingData) {
      stationName.add(data['주유소']!);
    }
    for (int i = 0; i < stationName.length; i++) {
      for (int j = 0; j < stationName.length; j++) {
        if (i != j) {
          if (stationName[i] == stationName[j]) {
            overlapName.add(stationName[i]);
          }
        }
      }
    }
    overlapName = overlapName.toSet().toList();
    int count;
    int sum = 0;
    for (String name in overlapName) {
      count = stationName.where((element) => element == name).length;
      print('$name 은 $count 개 있습니다.');
      sum = sum + count;
    }
    print('주유소 개수는 총 ${existingData.length} 개 입니다.');
    print('중복되는 주유소는 총 $sum 개 입니다.');
  }
}

Future<void> getOpinetCrawlingData() async {
  final file = File('json/oil_price_data.json');
  var sidoSigunData = json.decode(await File('json/sido_sigun_code.json').readAsString());
  List sidoNameList = (sidoSigunData['SIDO'] as List).map((e) => e["AREA_NM"]).toList(); //모든 시도코드 반환
  Map<String, dynamic> sidoSigunNameMap = {};
  int delaySeconds = 2;

  // 모든 시군네임 반환
  for (var sidoName in sidoNameList.sublist(0, 1)) {
    List sigunNameList = [];
    for (var data in sidoSigunData['SIDO']) {
      if (data['AREA_NM'] == sidoName) {
        for (var sigun in data['SIGUN']) {
          sigunNameList.add(sigun['AREA_NM']);
        }
      }
    }
    sidoSigunNameMap.addAll({sidoName: sigunNameList});
  }
  print('sidoSigunNameMap = $sidoSigunNameMap');

  String url = "https://www.opinet.co.kr/searRgSelect.do";
  String downloadPath = '/excel';
  var driver = await createDriver(desired: {
    'browserName': 'chrome',
    'chromeOptions': {
      'args': [
        // '--headless', // (선택) 헤드리스 모드
        '--no-sandbox',
      ],
      'prefs': {
        'download.default_directory': downloadPath,
        'download.prompt_for_download': false,
        'download.directory_upgrade': true,
      }
    },
    'port': 9515
  });

  try {
    // URL 열기
    await driver.get(url);

    // 페이지 로드 대기
    await Future.delayed(Duration(seconds: delaySeconds));

    // 시/도 선택 요소 찾기
    var sido = await driver.findElement(By.xpath('//*[@id="SIDO_NM0"]'));

    for (String sidoName in sidoNameList.sublist(0, 1)) {
      // 시/도 데이터 입력
      await sido.sendKeys(sidoName);
      await Future.delayed(Duration(seconds: delaySeconds));

      // 시/군/구 선택 요소 찾기
      var sigungu = await driver.findElement(By.xpath('//*[@id="SIGUNGU_NM0"]'));

      for (var sigunName in sidoSigunNameMap[sido]) {
        // 시/군/구 데이터 입력
        await sigungu.sendKeys(sigunName);
        await Future.delayed(Duration(seconds: delaySeconds));

        // 조회 버튼 클릭
        var searchButton = await driver.findElement(By.xpath('//*[@id="searRgSelect"]'));
        await searchButton.click(); // 비동기 작업이 완료될 때까지 기다림
        await Future.delayed(Duration(seconds: delaySeconds));

        // 엑셀 저장 버튼 클릭
        var excelButton = await driver.findElement(By.xpath('//a[@class="btn_type6_ex_save"]'));
        await excelButton.click(); // 비동기 작업이 완료될 때까지 기다림

        File downloadedFile = File('$downloadPath/지역_위치별(주유소).xls');
        String fileName = '$sidoName-$sigunName-oildata.xls';
        File newFile = File('$downloadPath/$fileName.xls');
        bool isDownload = false;
        while (!isDownload) {
          // 파일이 존재하는지 확인
          if (await file.exists()) {
            print('다운로드가 완료되었습니다.');
            isDownload = true;
            // 추가 작업 수행
          } else {
            await Future.delayed(Duration(seconds: 1));
            print('다운로드가 아직 완료되지 않았습니다. 1초 후 다시 확인합니다.');
          }
        }
        downloadedFile.rename(newFile.path);
      }
    }
  } finally {
    // 드라이버 종료
    await driver.quit();
  }
}
