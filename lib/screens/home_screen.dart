import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/task_provider.dart';
import 'day_view.dart';
import 'add_task_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late PageController _pageController;
  final int _initialPage = 10000;
  late DateTime _selectedDate;
  late DateTime _baseDate;
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _initialPage);

    final now = DateTime.now();
    _baseDate = DateTime(now.year, now.month, now.day);
    _selectedDate = _baseDate;

    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskProvider>().loadTasksForDate(_selectedDate);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    final daysDifference = index - _initialPage;
    final newDate = _baseDate.add(Duration(days: daysDifference));

    if (newDate.year == _selectedDate.year &&
        newDate.month == _selectedDate.month &&
        newDate.day == _selectedDate.day) {
      return;
    }

    setState(() {
      _selectedDate = newDate;
    });

    // Preload data for the new date
    context.read<TaskProvider>().loadTasksForDate(newDate);
  }

  void _jumpToDate(DateTime date, {bool animate = false}) {
    final targetDate = DateTime(date.year, date.month, date.day);

    // Calculate difference from base date
    final difference = targetDate.difference(_baseDate).inDays;
    final targetPage = _initialPage + difference;

    if (_pageController.hasClients) {
      if (animate) {
        _pageController.animateToPage(
          targetPage,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        _pageController.jumpToPage(targetPage);
      }
    }
  }

  void _jumpToToday() {
    _jumpToDate(DateTime.now(), animate: true);
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      _jumpToDate(picked, animate: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Light background
      body: SafeArea(
        child: Column(
          children: [
            if (_currentTab == 0) _buildWeekHeader(context),
            Expanded(
              child: _currentTab == 0
                  ? Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(30),
                          topRight: Radius.circular(30),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(30),
                          topRight: Radius.circular(30),
                        ),
                        child: PageView.builder(
                          controller: _pageController,
                          onPageChanged: _onPageChanged,
                          itemBuilder: (context, index) {
                            final daysDifference = index - _initialPage;
                            final date =
                                _baseDate.add(Duration(days: daysDifference));
                            return DayView(date: date);
                          },
                        ),
                      ),
                    )
                  : const SettingsScreen(),
            ),
          ],
        ),
      ),
      floatingActionButton: _currentTab == 0
          ? FloatingActionButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        AddTaskScreen(initialDate: _selectedDate),
                  ),
                );
              },
              child: const Icon(Icons.add),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.calendar_today,
                  color: _currentTab == 0
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey),
              onPressed: () {
                if (_currentTab == 0) {
                  _jumpToToday();
                } else {
                  setState(() => _currentTab = 0);
                }
              },
            ),
            IconButton(
              icon: Icon(Icons.settings,
                  color: _currentTab == 1
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey),
              onPressed: () => setState(() => _currentTab = 1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekHeader(BuildContext context) {
    // Generate dates for the week view (e.g., -3 to +3 days from selected)
    // Actually, typically week headers show a static week or scrollable.
    // For simplicity, let's show 7 days centered on selected date for now,
    // or better, standard week view.
    // Let's emulate the screenshot: "6. January 2026" title, then row of days.

    final weekDates = List.generate(7, (index) {
      // Center the week around the selected date, or start from Monday?
      // Screenshot implies it might be Mon-Sun.
      // Let's find the Monday of the current selected date.
      final monday =
          _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
      return monday.add(Duration(days: index));
    });

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _selectDate(context),
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('d. MMMM yyyy').format(_selectedDate),
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: weekDates.map((date) {
              final isSelected = date.year == _selectedDate.year &&
                  date.month == _selectedDate.month &&
                  date.day == _selectedDate.day;
              final isToday = DateTime.now().year == date.year &&
                  DateTime.now().month == date.month &&
                  DateTime.now().day == date.day;

              return GestureDetector(
                onTap: () {
                  final difference = date.difference(_baseDate).inDays;
                  _pageController.jumpToPage(_initialPage + difference);
                },
                child: Column(
                  children: [
                    Text(
                      DateFormat('E').format(date),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.black : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          date.day.toString(),
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    // Optional: Dots for tasks could go here if we query DB
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
