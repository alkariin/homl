import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:homl/data/models/device_session.dart';
import 'package:homl/data/repositories/users.repository.dart';

enum SessionsStatus { loading, loaded, failed }

class SessionsState extends Equatable {
  final SessionsStatus status;

  /// This device first, then the most recently active.
  final List<DeviceSession> sessions;

  /// A sign-out is on its way: the buttons wait.
  final bool busy;

  /// The last sign-out failed (the server out of reach): said once.
  final bool actionFailed;

  const SessionsState(
      {this.status = SessionsStatus.loading,
      this.sessions = const [],
      this.busy = false,
      this.actionFailed = false});

  SessionsState copyWith(
          {SessionsStatus? status,
          List<DeviceSession>? sessions,
          bool? busy,
          bool? actionFailed}) =>
      SessionsState(
          status: status ?? this.status,
          sessions: sessions ?? this.sessions,
          busy: busy ?? this.busy,
          actionFailed: actionFailed ?? this.actionFailed);

  bool get hasOthers => sessions.any((session) => !session.current);

  @override
  List<Object?> get props => [status, sessions, busy, actionFailed];
}

/// The signed-in devices of the account, and signing them out. Online only:
/// the list is the server's.
class SessionsCubit extends Cubit<SessionsState> {
  final UsersRepository _users;

  SessionsCubit(this._users) : super(const SessionsState());

  Future<void> load() async {
    emit(state.copyWith(status: SessionsStatus.loading, actionFailed: false));
    try {
      final sessions = await _users.listSessions();
      if (!isClosed) {
        emit(state.copyWith(status: SessionsStatus.loaded, sessions: sessions));
      }
    } on SessionsRequestFailure {
      if (!isClosed) emit(state.copyWith(status: SessionsStatus.failed));
    }
  }

  Future<void> signOut(String id) => _act(() => _users.revokeSession(id));

  Future<void> signOutOthers() => _act(_users.revokeOtherSessions);

  /// Runs a sign-out, then reads the list again (it changed, or something
  /// else did meanwhile).
  Future<void> _act(Future<void> Function() action) async {
    emit(state.copyWith(busy: true, actionFailed: false));
    try {
      await action();
    } on SessionsRequestFailure {
      if (!isClosed) emit(state.copyWith(busy: false, actionFailed: true));
      return;
    }
    if (isClosed) return;
    emit(state.copyWith(busy: false));
    await load();
  }
}
