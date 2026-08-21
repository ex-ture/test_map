import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test_map/models/place.dart';
import 'package:test_map/repositories/google_places_repository.dart';

void main() {
  group('GooglePlacesRepository.fetchPlaces', () {
    test('sends a Nearby Search request and maps valid places', () async {
      late http.Request capturedRequest;
      final MockClient client = MockClient((http.Request request) async {
        capturedRequest = request;
        return http.Response.bytes(
          utf8.encode(
            jsonEncode(<String, Object>{
              'places': <Object>[
                <String, Object>{
                  'id': 'nearby-cafe',
                  'displayName': <String, String>{'text': '近くのカフェ'},
                  'formattedAddress': '東京都千代田区丸の内1丁目',
                  'location': <String, double>{
                    'latitude': 35.6815,
                    'longitude': 139.7674,
                  },
                  'currentOpeningHours': <String, bool>{'openNow': true},
                },
              ],
            }),
          ),
          200,
          headers: <String, String>{
            'content-type': 'application/json; charset=utf-8',
          },
        );
      });
      final GooglePlacesRepository repository = GooglePlacesRepository(
        client: client,
        apiKey: 'test-api-key',
      );

      final List<Place> places = await repository.fetchPlaces(
        latitude: 35.681236,
        longitude: 139.767125,
        radiusMeters: 1000,
        maxResultCount: 10,
      );

      expect(
        capturedRequest.url.toString(),
        'https://places.googleapis.com/v1/places:searchNearby',
      );
      expect(capturedRequest.method, 'POST');
      expect(capturedRequest.headers['Content-Type'], 'application/json');
      expect(capturedRequest.headers['X-Goog-Api-Key'], 'test-api-key');
      expect(
        capturedRequest.headers['X-Goog-FieldMask'],
        'places.id,places.displayName,places.formattedAddress,places.location,'
        'places.currentOpeningHours',
      );

      final Map<String, dynamic> body =
          jsonDecode(capturedRequest.body) as Map<String, dynamic>;
      expect(body['includedTypes'], <String>['cafe', 'coffee_shop']);
      expect(body['maxResultCount'], 10);
      expect(body['languageCode'], 'ja');
      expect(body['regionCode'], 'JP');
      expect(body['rankPreference'], 'DISTANCE');
      expect(
        body['locationRestriction'],
        containsPair('circle', isA<Map<String, dynamic>>()),
      );

      expect(places, hasLength(1));
      expect(places.single.name, '近くのカフェ');
      expect(places.single.isOpenNow, isTrue);
    });

    test('throws on malformed JSON', () async {
      final GooglePlacesRepository repository = GooglePlacesRepository(
        client: MockClient(
          (http.Request request) async => http.Response('{invalid', 200),
        ),
        apiKey: 'test-api-key',
      );

      await expectLater(
        repository.fetchPlaces(
          latitude: 35.681236,
          longitude: 139.767125,
          radiusMeters: 1000,
          maxResultCount: 10,
        ),
        throwsFormatException,
      );
    });

    test('throws when the top-level JSON value is not an object', () async {
      final GooglePlacesRepository repository = GooglePlacesRepository(
        client: MockClient(
          (http.Request request) async => http.Response('[]', 200),
        ),
        apiKey: 'test-api-key',
      );

      await expectLater(
        repository.fetchPlaces(
          latitude: 35.681236,
          longitude: 139.767125,
          radiusMeters: 1000,
          maxResultCount: 10,
        ),
        throwsFormatException,
      );
    });
  });

  group('GooglePlacesRepository.searchPlacesByText', () {
    test('sends a Text Search request and maps valid places', () async {
      late http.Request capturedRequest;
      final MockClient client = MockClient((http.Request request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode(<String, Object>{
            'places': <Object>[
              <String, Object>{
                'id': 'inside-website',
                'displayName': <String, String>{'text': '近くのコンビニ'},
                'formattedAddress': '東京都千代田区丸の内1丁目',
                'location': <String, double>{
                  'latitude': 35.6815,
                  'longitude': 139.7674,
                },
                'websiteUri': 'https://example.test/store',
                'googleMapsUri': 'https://maps.google.com/inside-website',
                'currentOpeningHours': <String, bool>{'openNow': true},
              },
              <String, Object>{
                'id': 'inside-maps',
                'displayName': <String, String>{'text': '近くのジム'},
                'location': <String, double>{
                  'latitude': 35.6820,
                  'longitude': 139.7678,
                },
                'googleMapsUri': 'https://maps.google.com/inside-maps',
              },
              <String, Object>{
                'id': 'outside-radius',
                'displayName': <String, String>{'text': '遠くの病院'},
                'location': <String, double>{
                  'latitude': 35.7812,
                  'longitude': 139.7671,
                },
                'googleMapsUri': 'https://maps.google.com/outside-radius',
              },
              <String, Object>{
                'id': 'missing-location',
                'displayName': <String, String>{'text': '位置なし'},
              },
            ],
          }),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });
      final GooglePlacesRepository repository = GooglePlacesRepository(
        client: client,
        apiKey: 'test-api-key',
      );

      final List<Place> places = await repository.searchPlacesByText(
        query: ' コンビニ ',
        latitude: 35.681236,
        longitude: 139.767125,
        radiusMeters: 1500,
        maxResultCount: 10,
      );

      expect(
        capturedRequest.url.toString(),
        'https://places.googleapis.com/v1/places:searchText',
      );
      expect(capturedRequest.method, 'POST');
      expect(capturedRequest.headers['X-Goog-Api-Key'], 'test-api-key');
      expect(
        capturedRequest.headers['X-Goog-FieldMask'],
        'places.id,places.displayName,places.formattedAddress,places.location,'
        'places.currentOpeningHours',
      );

      final Map<String, dynamic> body =
          jsonDecode(capturedRequest.body) as Map<String, dynamic>;
      expect(body['textQuery'], 'コンビニ');
      expect(body['pageSize'], 10);
      expect(body, isNot(contains('includedTypes')));
      expect(
        body['locationRestriction'],
        containsPair('rectangle', isA<Map<String, dynamic>>()),
      );

      expect(places, hasLength(2));
      expect(places.first.name, '近くのコンビニ');
      expect(places.first.description, '東京都千代田区丸の内1丁目');
      expect(places.first.webUrl, 'https://example.com');
      expect(places.first.isOpenNow, isTrue);
      expect(places.last.webUrl, 'https://example.com');
    });

    test('uses the placeholder URL when response URLs are missing', () async {
      final MockClient client = MockClient((http.Request request) async {
        return http.Response.bytes(
          utf8.encode(
            jsonEncode(<String, Object>{
              'places': <Object>[
                <String, Object>{
                  'id': 'fallback-url',
                  'displayName': <String, String>{'text': 'ラーメン店'},
                  'location': <String, double>{
                    'latitude': 35.6815,
                    'longitude': 139.7674,
                  },
                },
              ],
            }),
          ),
          200,
          headers: <String, String>{
            'content-type': 'application/json; charset=utf-8',
          },
        );
      });
      final GooglePlacesRepository repository = GooglePlacesRepository(
        client: client,
        apiKey: 'test-api-key',
      );

      final List<Place> places = await repository.searchPlacesByText(
        query: 'ラーメン',
        latitude: 35.681236,
        longitude: 139.767125,
        radiusMeters: 1500,
      );

      expect(places, hasLength(1));
      expect(places.single.webUrl, 'https://example.com');
    });

    test('rejects an empty query without sending a request', () async {
      int requestCount = 0;
      final MockClient client = MockClient((http.Request request) async {
        requestCount++;
        return http.Response('{}', 200);
      });
      final GooglePlacesRepository repository = GooglePlacesRepository(
        client: client,
        apiKey: 'test-api-key',
      );

      await expectLater(
        repository.searchPlacesByText(
          query: '   ',
          latitude: 35.681236,
          longitude: 139.767125,
          radiusMeters: 1500,
        ),
        throwsArgumentError,
      );
      expect(requestCount, 0);
    });

    test('throws on an API error response', () async {
      final MockClient client = MockClient(
        (http.Request request) async =>
            http.Response('{"error":{"message":"invalid request"}}', 400),
      );
      final GooglePlacesRepository repository = GooglePlacesRepository(
        client: client,
        apiKey: 'test-api-key',
      );

      await expectLater(
        repository.searchPlacesByText(
          query: '病院',
          latitude: 35.681236,
          longitude: 139.767125,
          radiusMeters: 1500,
        ),
        throwsException,
      );
    });
  });

  group('GooglePlacesRepository.fetchAutocompleteSuggestions', () {
    test(
      'sends a location-biased request and maps place and query results',
      () async {
        late http.Request capturedRequest;
        final MockClient client = MockClient((http.Request request) async {
          capturedRequest = request;
          return http.Response.bytes(
            utf8.encode(
              jsonEncode(<String, Object>{
                'suggestions': <Object>[
                  <String, Object>{
                    'placePrediction': <String, Object>{
                      'placeId': 'place-id-1',
                      'text': <String, String>{'text': 'コンビニ 神田店'},
                    },
                  },
                  <String, Object>{
                    'queryPrediction': <String, Object>{
                      'text': <String, String>{'text': 'コンビニ 周辺'},
                    },
                  },
                ],
              }),
            ),
            200,
            headers: <String, String>{
              'content-type': 'application/json; charset=utf-8',
            },
          );
        });
        final GooglePlacesRepository repository = GooglePlacesRepository(
          client: client,
          apiKey: 'test-api-key',
        );

        final suggestions = await repository.fetchAutocompleteSuggestions(
          input: ' コンビニ ',
          latitude: 35.681236,
          longitude: 139.767125,
          radiusMeters: 1000,
        );

        expect(
          capturedRequest.url.toString(),
          'https://places.googleapis.com/v1/places:autocomplete',
        );
        expect(capturedRequest.method, 'POST');
        expect(capturedRequest.headers['X-Goog-Api-Key'], 'test-api-key');
        expect(
          capturedRequest.headers['X-Goog-FieldMask'],
          'suggestions.placePrediction.placeId,'
          'suggestions.placePrediction.text.text,'
          'suggestions.queryPrediction.text.text',
        );

        final Map<String, dynamic> body =
            jsonDecode(capturedRequest.body) as Map<String, dynamic>;
        expect(body['input'], 'コンビニ');
        expect(body['languageCode'], 'ja');
        expect(body['regionCode'], 'JP');
        expect(body['includeQueryPredictions'], isTrue);
        expect(
          body['locationBias'],
          containsPair('circle', isA<Map<String, dynamic>>()),
        );

        expect(suggestions, hasLength(2));
        expect(suggestions.first.text, 'コンビニ 神田店');
        expect(suggestions.first.placeId, 'place-id-1');
        expect(suggestions.last.text, 'コンビニ 周辺');
      },
    );

    test('does not send a request for empty input', () async {
      int requestCount = 0;
      final GooglePlacesRepository repository = GooglePlacesRepository(
        client: MockClient((http.Request request) async {
          requestCount++;
          return http.Response('{}', 200);
        }),
        apiKey: 'test-api-key',
      );

      final suggestions = await repository.fetchAutocompleteSuggestions(
        input: '   ',
        latitude: 35.681236,
        longitude: 139.767125,
        radiusMeters: 1000,
      );

      expect(suggestions, isEmpty);
      expect(requestCount, 0);
    });
  });
}
