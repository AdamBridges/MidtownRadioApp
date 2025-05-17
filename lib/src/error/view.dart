import 'package:ctwr_midtown_radio_app/main.dart';
import 'package:ctwr_midtown_radio_app/src/open_url.dart';
import 'package:flutter/material.dart';
import 'package:ctwr_midtown_radio_app/src/home/view.dart';

class ErrorPage extends StatelessWidget {
  const ErrorPage({
    super.key,
    required this.error,
    required this.stackTrace
  });

  static const routeName = '/error';
  static const String title = 'Oops! Something Went Wrong';
  final String? stackTrace;
  final String error;


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(title),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 80,
              color: colorScheme.error,
            ),
            const SizedBox(height: 24),
            Text(
              'We encountered an issue',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              color: colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Error Details:',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onErrorContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Please ensure you are connected to the internet and try again.',
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16.0,
              runSpacing: 12.0,
              children: [
                FilledButton.tonal(
                  onPressed: () {
                    Navigator.pushReplacementNamed(
                      context, 
                      HomePage.routeName
                    );
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24, 
                      vertical: 16
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.home_rounded),
                      SizedBox(width: 8),
                      Text('Return Home'),
                    ],
                  ),
                ),

                FilledButton(
                  onPressed: () => openUrl(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.error,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24, 
                      vertical: 16
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bug_report_rounded),
                      SizedBox(width: 8),
                      Text('Report Issue'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ), 
    );
  }
}