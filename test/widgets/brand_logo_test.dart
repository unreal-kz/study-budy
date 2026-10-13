// test/widgets/brand_logo_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_budy/widgets/brand_logo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders the brand mark at the requested size', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Center(child: BrandLogo(size: 96))),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.width, 96);
    expect(image.height, 96);
    expect(image.semanticLabel, 'Study Buddy logo');
  });

  test('brand asset is declared in pubspec and bundled', () async {
    final data = await rootBundle.load(BrandLogo.assetPath);
    expect(data.lengthInBytes, greaterThan(0));
  });
}
