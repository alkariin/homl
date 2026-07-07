import 'dart:async';

import 'package:dio/dio.dart';
import 'package:homl/data/models/user.dart';

import 'package:homl/helpers/language.dart';
import 'package:homl/helpers/local_storage_manager.dart';

import 'api.dart';

/// Exception thrown when login fails
class UserRequestFailure implements Exception {}

/// Exception thrown when the access token is not found
class UserNotFoundFailure implements Exception {}

class UserOtherFailure implements Exception {}

class UsersRepository {
  late final apiInstance = Api();

  Future<AuthenticationStatus> login(String username, String password) async {
    late Response<dynamic> response;
    try {
      response = await apiInstance.api.post('/login', data: {
        'username': username,
        'password': password,
      });
    } on DioException catch (err) {
      if (err.response?.statusCode == 401) {
        throw UserRequestFailure();
      }
      throw UserOtherFailure();
    }

    if (response.data == null || !response.data!.containsKey('refresh_token')) {
      throw UserNotFoundFailure();
    }

    LocalStorageManager.setValue(
        LocalStorageKey.refreshToken, response.data!['refresh_token']);
    apiInstance.accessToken = response.data!['access_token'];
    apiInstance.updateStatus(AuthenticationStatus.authenticated);

    return AuthenticationStatus.authenticated;
  }

  Future<AuthenticationStatus> register(
      String username, String password, Language language) async {
    final response = await apiInstance.api.post('/registration', data: {
      'username': username,
      'password': password,
      'language': language.name,
    });

    if (response.data == null || !response.data!.containsKey('refresh_token')) {
      throw UserNotFoundFailure();
    }

    LocalStorageManager.setValue(
        LocalStorageKey.refreshToken, response.data!['refresh_token']);
    apiInstance.accessToken = response.data!['access_token'];
    apiInstance.updateStatus(AuthenticationStatus.authenticated);

    return AuthenticationStatus.authenticated;
  }

  void logout() async {
    try {
      await apiInstance.api.post('/logout'); // doesn't work without await
    } finally {
      LocalStorageManager.remove(LocalStorageKey.refreshToken);
      apiInstance.accessToken = null;
      apiInstance.updateStatus(AuthenticationStatus.unauthenticated);
    }
  }

  Future<void> updatePassword(String oldPassword, String newPassword) async {
    late Response<dynamic> response;
    try {
      response = await apiInstance.api.put('/password',
          data: {'oldPassword': oldPassword, 'newPassword': newPassword});
    } on DioException catch (err) {
      if (err.response?.statusCode == 401) {
        throw UserRequestFailure();
      }
      throw UserOtherFailure();
    }

    if (response.data == null || !response.data.containsKey('refresh_token')) {
      throw UserOtherFailure();
    }

    LocalStorageManager.setValue(
        LocalStorageKey.refreshToken, response.data['refresh_token']);
    apiInstance.accessToken = response.data['access_token'];
  }

  Future<User> secureAuth(User user) async {
    late Response<User> response;
    try {
      response =
          await apiInstance.api.put<User>('/secureAuth', data: user.toJson());
    } on DioException catch (err) {
      if (err.response?.statusCode == 401) {
        throw UserRequestFailure();
      }
      throw UserOtherFailure();
    }

    if (response.data == null) {
      throw UserOtherFailure();
    }

    return response.data!;
  }
}
