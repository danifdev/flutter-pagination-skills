// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

///
/// [ Introduction with packages ]
///  Used packages flutter_bloc: ^8.1.2
///

void main(List<String> args) {
  runApp(
    const TodoApp(),
  );
}

class TodoApp extends StatelessWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    /// [ Note ]
    /// We must register bloc before use it anywhere else for ex: if u have 2 screen and 1-> A, 2-> B then u need blocA in B screen
    /// then u must register it before routing to B screen.
    /// Inkwell ( onTap:()=> MaterialPageRoute(
    //   builder: (context) => BlocProvider(
    //     create: (context) => BlocA,
    //     child: B,
    //   ),
    // ) ,)
    /// OR Entering of app.
    return BlocProvider(
      create: (context) => TodoBloc()..add(FetchTodoListEvent()),
      child: const MaterialApp(
        home: PaginatedListView(),
      ),
    );
  }
}

///
/// [ Enums and Base used classes ]
///
void clog<T>(T v) => log('========    $v   =========');

enum FetchingTodoListStatus { initial, loading, success, failure }

class Todo extends Equatable {
  final String id;
  final String? name;

  const Todo({required this.id, this.name});

  @override
  String toString() => 'Todo(id: $id, name: $name)';

  @override
  List<Object?> get props => [id, name];
}

///
/// [Business logic with bloc pattern]
///

class TodoBloc extends Bloc<TodoEvent, TodoState> {
  TodoBloc() : super(TodoState()) {
    on<FetchTodoListEvent>(_fetchingTodoList);
  }

  FutureOr<void> _fetchingTodoList(
      FetchTodoListEvent event, Emitter<TodoState> emit) async {
    // Checking if hasReachedMax value for stopping api call.
    if (state.hasReachedMax) {
      clog(
          'MAXX ==> ${state.hasReachedMax} \n Bro Reached Max ==> ${state.todoList?.length}');
      return;
    }
    try {
      // Fetching any list from any Repository
      await Future.delayed(
        const Duration(seconds: 2),
        () {
          final randomIndex = math.Random().nextInt(50);
          final previousStateList = state.todoList;
          final isInitialStatus =
              state.status == FetchingTodoListStatus.initial;

          // First call fetching first 10 or any item list when initial
          // and completing by returning emitting state with first 10 items
          // second call we skip and continue fetching other page items
          if (isInitialStatus) {
            final response = _fetchingList(randomIndex).toList();
            final List<Todo> newList = List.from(previousStateList ?? [])
              ..addAll(response);
            return emit(
              state.update(
                status: FetchingTodoListStatus.success,
                todoList: newList,
              ),
            );
          }

          // We do not need to keep page count on State, we can determine which page we have to fetch with by (mod 10),
          // if state list has 20 then, page = 20 / 10 = 2; then we have to fetch page = page + 1;
          final page = ((previousStateList?.length ?? 0) / 10) + 1;

          final response = _fetchingList(randomIndex).toList();

          /// [ NOTE]
          /// We have to change the state as equality! ex: [previousState = newState]
          ///

          final List<Todo> newList = List.from(previousStateList ?? [])
            ..addAll(response);

          // You have known that limit of page  from Api
          final hasReachedMaxWhen = page > 5;

          emit(
            state.update(
              status: FetchingTodoListStatus.success,
              todoList: newList,
              hasReachedMax: hasReachedMaxWhen,
            ),
          );
        },
      );
    } catch (ex) {
      emit(
        state.update(
          status: FetchingTodoListStatus.failure,
          stateErrorMessage: 'Ups, something went Wrong.... ${ex.toString()}',
        ),
      );
    }
  }

  List<Todo> _fetchingList(int randomIndex) {
    return List.generate(
      10,
      (i) => Todo(
        id: '${randomIndex + i}',
        name: 'Todo $i',
      ),
    );
  }
}

///
/// [Bloc events]
///
abstract class TodoEvent {}

class FetchTodoListEvent extends TodoEvent {}

///
/// [Bloc state]
///
class TodoState {
  final FetchingTodoListStatus status;
  final List<Todo>? todoList;
  final String? stateErrorMessage;
  final bool hasReachedMax;

  TodoState({
    this.status = FetchingTodoListStatus.initial,
    this.todoList,
    this.stateErrorMessage,
    this.hasReachedMax = false,
  });

  Widget when({
    required Widget initial,
    Widget? loading,
    required Widget success,
    required Widget failure,
  }) {
    switch (status) {
      case FetchingTodoListStatus.initial:
        return initial;
      case FetchingTodoListStatus.failure:
        return failure;
      case FetchingTodoListStatus.success:
        return loading ?? success;
      case FetchingTodoListStatus.loading:
        return success;
      default:
        return const SizedBox();
    }
  }

  TodoState update({
    FetchingTodoListStatus? status,
    List<Todo>? todoList,
    String? stateErrorMessage,
    bool? hasReachedMax,
  }) {
    return TodoState(
      status: status ?? this.status,
      stateErrorMessage: stateErrorMessage ?? this.stateErrorMessage,
      todoList: todoList ?? this.todoList,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
    );
  }
}

///
/// [------ UI ---- ]
///
class PaginatedListView extends StatefulWidget {
  const PaginatedListView({super.key});

  @override
  State<PaginatedListView> createState() => _PaginatedListViewState();
}

class _PaginatedListViewState extends State<PaginatedListView> {
  late ScrollController _scrollController;
  late TodoBloc bloc;

  DateTime initialFetchTime = DateTime.now();

  @override
  void initState() {
    bloc = BlocProvider.of<TodoBloc>(context);
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    super.initState();
  }

  void _onScroll() {
    if (_isBottom) {
      final mayFetch = _fetchDroppable();
      if (mayFetch) {
        bloc.add(FetchTodoListEvent());
        setState(() {
          initialFetchTime = DateTime.now();
        });
      }
    }
  }

// Aware request from continuously calling by scrolling
  bool _fetchDroppable() {
    final currentFetchTime = DateTime.now();
    final isMayFetchingList =
        (currentFetchTime.difference(initialFetchTime).inMilliseconds >= 1000);
    return isMayFetchingList;
  }

// Detecting reached bottom for fetching next page
  bool get _isBottom {
    if (!_scrollController.hasClients) return false;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    return currentScroll >= (maxScroll * .9);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: _appBar(),
        body: _body(),
      ),
    );
  }

  Widget _body() {
    return Padding(
      padding: lowPadding,
      child: BlocBuilder<TodoBloc, TodoState>(
        builder: (_, state) {
          return state.when(
            initial: const _LoadingIndicator(),
            success: () {
              final list = state.todoList;
              final itemCount = list?.length ?? 0;
              return ListView.separated(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                separatorBuilder: (context, index) => verSpace,
                // Because we need to show loading or "No more data" at last index of List
                // so we need add one more element
                itemCount: itemCount + 1,
                itemBuilder: (context, index) {
                  // Showing last index 'No more DATA message'
                  if (state.hasReachedMax && index >= itemCount) {
                    return const _NoMoreDataWidget();
                  }

                  // Showing last index loading indicator
                  if (index >= itemCount) return const _LoadingIndicator();

                  final todo = list?[index];
                  return ListTile(
                    tileColor: Colors.black12,
                    leading: Text(todo?.id ?? '-'),
                    title: Text(todo?.name ?? '-'),
                  );
                },
              );
            }(),
            failure: Center(
              child: Text(state.stateErrorMessage ?? ''),
            ),
          );
        },
      ),
    );
  }

  AppBar _appBar() => AppBar(title: const Text('Paginated todo list'));

  SizedBox get verSpace => const SizedBox(height: 12);
  EdgeInsets get lowPadding => const EdgeInsets.all(8);
}

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 50,
        height: 50,
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _NoMoreDataWidget extends StatelessWidget {
  const _NoMoreDataWidget();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Text('No more Data bro....'),
      ),
    );
  }
}
