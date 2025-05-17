// TODO: I noticed an error with midtown conversations - "New Music 2024: Conversations with Red Output and Living Room for Small"
// ^ this does not work for some reason on the app, despite working on my browser
// I have no idea why - I tried to figure it out but havent been able to

import 'package:ctwr_midtown_radio_app/src/on_demand/controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ctwr_midtown_radio_app/src/app.dart';
import 'package:ctwr_midtown_radio_app/src/settings/controller.dart';
import 'package:ctwr_midtown_radio_app/src/settings/service.dart';

import 'package:audio_service/audio_service.dart';

import 'package:ctwr_midtown_radio_app/src/media_player/audio_player_handler.dart';

// Initiate singleton for app access to system audio controls
late AudioHandler audioHandler;
late AudioPlayerHandler audioPlayerHandler;
void main() async {
  // Ensure that plugin services are initialized
  WidgetsFlutterBinding.ensureInitialized();

  final settingsController = SettingsController(SettingsService());
  await settingsController.loadSettings();
  OnDemand.primeCache(); 

  audioPlayerHandler = AudioPlayerHandler();
  
  audioHandler = await AudioService.init(
    builder: () => audioPlayerHandler,
    config: AudioServiceConfig(
      androidNotificationChannelId: 'com.civitechwr.midtownradio.app',
      androidNotificationChannelName: 'Audio playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidNotificationIcon: 'mipmap/launcher_icon'
    ),
    
  );
  
  // Load settings
  await settingsController.loadSettings();

  // Load settings
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  runApp(MidtownRadioApp(settingsController: settingsController));

}