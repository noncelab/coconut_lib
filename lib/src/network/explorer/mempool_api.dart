part of '../../../coconut_lib.dart';

class MempoolApi {
  /// example: `https://mempool.space`
  static String host = 'https://regtest-mempool.coconut.onl';

  static Future<RecommendedFee> getRecommendFee() async {
    String urlString = '$host/api/v1/fees/recommended';
    final url = Uri.parse(urlString);
    final response = await get(url);

    Map<String, dynamic> jsonMap = jsonDecode(response.body);

    return RecommendedFee.fromJson(jsonMap);
  }
}
