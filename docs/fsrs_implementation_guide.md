# FSRS Implementation Guide for Flashcard App

## Table of Contents
1. [Quick Start Guide](#quick-start-guide)
2. [Required Data Structure](#required-data-structure)
3. [Integration Steps](#integration-steps)
4. [Code Examples](#code-examples)
5. [Explaining to Your Team](#explaining-to-your-team)
6. [Database Schema](#database-schema)
7. [Common Pitfalls](#common-pitfalls)

---

## Quick Start Guide

### What is FSRS?
FSRS (Free Spaced Repetition Scheduler) is a smart algorithm that determines **when** you should review each flashcard to maximize learning efficiency. Think of it as an AI tutor that knows the perfect time to quiz you on each card.

### The 30-Second Explanation
- User reviews a card and rates it (Again/Hard/Good/Easy)
- FSRS calculates when to show that card next
- Cards you find easy are shown less frequently
- Cards you struggle with are shown more often
- The algorithm adapts to YOUR learning patterns

---

## Required Data Structure

### Essential Card Data

Each flashcard needs to store these fields:

```dart
class Flashcard {
  // REQUIRED: Core identification
  final int cardId;                    // Unique identifier
  
  // REQUIRED: Your card content
  final String front;                  // Question/prompt
  final String back;                   // Answer
  
  // REQUIRED: FSRS scheduling data
  State state;                         // learning, review, or relearning
  int? step;                          // Current learning step (0, 1, 2...)
  double? stability;                  // Memory strength (in days)
  double? difficulty;                 // How hard this card is (1-10)
  DateTime due;                       // When to show this card next
  DateTime? lastReview;              // When last reviewed
  
  // OPTIONAL: Helpful metadata
  DateTime createdAt;                // When card was created
  int totalReviews;                  // Count of all reviews
  String? deckId;                    // Which deck it belongs to
}
```

### Review History Data

Each time a card is reviewed, store:

```dart
class ReviewLog {
  final int cardId;                  // Which card was reviewed
  final Rating rating;               // again, hard, good, or easy
  final DateTime reviewDateTime;     // When it happened
  final int? reviewDuration;        // How long it took (milliseconds)
}
```

### Minimum Viable Data

At the absolute minimum, you need:
1. **cardId** - to track the card
2. **state** - learning/review/relearning
3. **stability** - memory strength
4. **difficulty** - card hardness
5. **due** - next review date
6. **lastReview** - last review date

---

## Integration Steps

### Step 1: Initialize the Scheduler

Create ONE scheduler for your entire app (or one per user if you want custom settings):

```dart
class StudySession {
  late final Scheduler scheduler;
  
  void initialize() {
    scheduler = Scheduler(
      desiredRetention: 0.9,           // 90% target recall
      learningSteps: [
        Duration(minutes: 1),          // First review after 1 min
        Duration(minutes: 10),         // Second review after 10 min
      ],
      relearningSteps: [
        Duration(minutes: 10),         // Review forgotten cards after 10 min
      ],
      maximumInterval: 365,            // Don't wait more than 1 year
      enableFuzzing: true,             // Add randomness to intervals
    );
  }
}
```

### Step 2: Create New Cards

When a user creates a new flashcard:

```dart
Future<Flashcard> createNewCard(String front, String back) async {
  // Create the FSRS card
  final fsrsCard = await Card.create(
    state: State.learning,
    step: 0,
  );
  
  // Create your flashcard with FSRS data
  final flashcard = Flashcard(
    cardId: fsrsCard.cardId,
    front: front,
    back: back,
    state: fsrsCard.state,
    step: fsrsCard.step,
    stability: null,              // Not calculated until first review
    difficulty: null,             // Not calculated until first review
    due: fsrsCard.due,           // Due immediately (now)
    lastReview: null,
    createdAt: DateTime.now(),
    totalReviews: 0,
  );
  
  // Save to database
  await saveToDatabase(flashcard);
  
  return flashcard;
}
```

### Step 3: Get Due Cards

When user starts a study session:

```dart
Future<List<Flashcard>> getDueCards() async {
  final now = DateTime.now().toUtc();
  
  // Query database for cards where due <= now
  final dueCards = await database.query(
    'SELECT * FROM flashcards WHERE due <= ?',
    [now.toIso8601String()],
  );
  
  return dueCards.map((row) => Flashcard.fromMap(row)).toList();
}
```

### Step 4: Review a Card

When user reviews a card:

```dart
Future<void> reviewCard(Flashcard flashcard, Rating rating) async {
  // Convert your flashcard to FSRS Card
  final fsrsCard = Card(
    cardId: flashcard.cardId,
    state: flashcard.state,
    step: flashcard.step,
    stability: flashcard.stability,
    difficulty: flashcard.difficulty,
    due: flashcard.due,
    lastReview: flashcard.lastReview,
  );
  
  // Review with FSRS scheduler
  final result = scheduler.reviewCard(
    fsrsCard,
    rating,
    reviewDateTime: DateTime.now().toUtc(),
  );
  
  // Update your flashcard with new FSRS data
  flashcard.state = result.card.state;
  flashcard.step = result.card.step;
  flashcard.stability = result.card.stability;
  flashcard.difficulty = result.card.difficulty;
  flashcard.due = result.card.due;
  flashcard.lastReview = result.card.lastReview;
  flashcard.totalReviews++;
  
  // Save updated card to database
  await updateInDatabase(flashcard);
  
  // Save review log for analytics
  await saveReviewLog(result.reviewLog);
}
```

### Step 5: Display UI Feedback

Show users helpful information:

```dart
class CardReviewScreen extends StatelessWidget {
  final Flashcard card;
  final Scheduler scheduler;
  
  Widget build(BuildContext context) {
    // Calculate retrievability (how well they know it)
    final fsrsCard = card.toFSRSCard();
    final retrievability = scheduler.getCardRetrievability(fsrsCard);
    final percentKnown = (retrievability * 100).round();
    
    return Column(
      children: [
        Text('Estimated recall: $percentKnown%'),
        Text('Difficulty: ${card.difficulty?.toStringAsFixed(1) ?? "New"}'),
        
        // Show what each button does
        RatingButtons(
          onAgain: () {
            showNextInterval(rating: Rating.again);
          },
          onHard: () {
            showNextInterval(rating: Rating.hard);
          },
          // ... etc
        ),
      ],
    );
  }
  
  void showNextInterval(Rating rating) {
    // Preview when card will be due next
    final fsrsCard = card.toFSRSCard();
    final result = scheduler.reviewCard(fsrsCard, rating);
    
    final nextDue = result.card.due;
    final interval = nextDue.difference(DateTime.now());
    
    print('Next review: ${formatInterval(interval)}');
  }
  
  String formatInterval(Duration interval) {
    if (interval.inDays > 0) {
      return '${interval.inDays} days';
    } else if (interval.inHours > 0) {
      return '${interval.inHours} hours';
    } else {
      return '${interval.inMinutes} minutes';
    }
  }
}
```

---

## Code Examples

### Complete Integration Example

```dart
// models/flashcard_model.dart
class Flashcard {
  final int cardId;
  final String front;
  final String back;
  State state;
  int? step;
  double? stability;
  double? difficulty;
  DateTime due;
  DateTime? lastReview;
  final DateTime createdAt;
  int totalReviews;
  
  Flashcard({
    required this.cardId,
    required this.front,
    required this.back,
    required this.state,
    this.step,
    this.stability,
    this.difficulty,
    required this.due,
    this.lastReview,
    required this.createdAt,
    this.totalReviews = 0,
  });
  
  // Convert to FSRS Card for scheduling
  Card toFSRSCard() {
    return Card(
      cardId: cardId,
      state: state,
      step: step,
      stability: stability,
      difficulty: difficulty,
      due: due,
      lastReview: lastReview,
    );
  }
  
  // Update from FSRS Card after review
  void updateFromFSRSCard(Card fsrsCard) {
    state = fsrsCard.state;
    step = fsrsCard.step;
    stability = fsrsCard.stability;
    difficulty = fsrsCard.difficulty;
    due = fsrsCard.due;
    lastReview = fsrsCard.lastReview;
  }
  
  Map<String, dynamic> toMap() {
    return {
      'cardId': cardId,
      'front': front,
      'back': back,
      'state': state.value,
      'step': step,
      'stability': stability,
      'difficulty': difficulty,
      'due': due.toIso8601String(),
      'lastReview': lastReview?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'totalReviews': totalReviews,
    };
  }
  
  factory Flashcard.fromMap(Map<String, dynamic> map) {
    return Flashcard(
      cardId: map['cardId'] as int,
      front: map['front'] as String,
      back: map['back'] as String,
      state: State.fromValue(map['state'] as int),
      step: map['step'] as int?,
      stability: map['stability'] as double?,
      difficulty: map['difficulty'] as double?,
      due: DateTime.parse(map['due'] as String),
      lastReview: map['lastReview'] != null 
          ? DateTime.parse(map['lastReview'] as String) 
          : null,
      createdAt: DateTime.parse(map['createdAt'] as String),
      totalReviews: map['totalReviews'] as int,
    );
  }
}

// services/study_service.dart
class StudyService {
  final Scheduler scheduler;
  final Database database;
  
  StudyService({
    required this.database,
    Scheduler? scheduler,
  }) : scheduler = scheduler ?? Scheduler();
  
  // Get all cards due for review
  Future<List<Flashcard>> getDueCards({String? deckId}) async {
    final now = DateTime.now().toUtc();
    
    String query = 'SELECT * FROM flashcards WHERE due <= ?';
    List<dynamic> args = [now.toIso8601String()];
    
    if (deckId != null) {
      query += ' AND deckId = ?';
      args.add(deckId);
    }
    
    query += ' ORDER BY due ASC';
    
    final results = await database.query(query, args);
    return results.map((row) => Flashcard.fromMap(row)).toList();
  }
  
  // Review a card with a rating
  Future<ReviewResult> reviewCard(
    Flashcard flashcard, 
    Rating rating,
  ) async {
    final startTime = DateTime.now();
    final fsrsCard = flashcard.toFSRSCard();
    
    // Use FSRS to calculate next review
    final result = scheduler.reviewCard(
      fsrsCard,
      rating,
      reviewDateTime: DateTime.now().toUtc(),
    );
    
    // Calculate review duration
    final duration = DateTime.now().difference(startTime).inMilliseconds;
    
    // Update flashcard
    flashcard.updateFromFSRSCard(result.card);
    flashcard.totalReviews++;
    
    // Save to database
    await database.update(
      'flashcards',
      flashcard.toMap(),
      where: 'cardId = ?',
      whereArgs: [flashcard.cardId],
    );
    
    // Save review log
    await database.insert(
      'review_logs',
      {
        'cardId': result.reviewLog.cardId,
        'rating': result.reviewLog.rating.value,
        'reviewDateTime': result.reviewLog.reviewDateTime.toIso8601String(),
        'reviewDuration': duration,
      },
    );
    
    return ReviewResult(
      flashcard: flashcard,
      nextDue: result.card.due,
      interval: result.card.due.difference(DateTime.now()),
    );
  }
  
  // Get statistics
  Future<StudyStats> getStats() async {
    final now = DateTime.now().toUtc();
    
    final dueCount = await database.query(
      'SELECT COUNT(*) as count FROM flashcards WHERE due <= ?',
      [now.toIso8601String()],
    );
    
    final newCount = await database.query(
      'SELECT COUNT(*) as count FROM flashcards WHERE state = ? AND lastReview IS NULL',
      [State.learning.value],
    );
    
    final reviewCount = await database.query(
      'SELECT COUNT(*) as count FROM flashcards WHERE state = ?',
      [State.review.value],
    );
    
    return StudyStats(
      dueCards: dueCount.first['count'] as int,
      newCards: newCount.first['count'] as int,
      reviewCards: reviewCount.first['count'] as int,
    );
  }
}

// Data classes
class ReviewResult {
  final Flashcard flashcard;
  final DateTime nextDue;
  final Duration interval;
  
  ReviewResult({
    required this.flashcard,
    required this.nextDue,
    required this.interval,
  });
}

class StudyStats {
  final int dueCards;
  final int newCards;
  final int reviewCards;
  
  StudyStats({
    required this.dueCards,
    required this.newCards,
    required this.reviewCards,
  });
}
```

### UI Implementation Example

```dart
// screens/study_screen.dart
class StudyScreen extends StatefulWidget {
  @override
  _StudyScreenState createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  final StudyService studyService = StudyService(database: myDatabase);
  List<Flashcard> dueCards = [];
  int currentIndex = 0;
  bool showAnswer = false;
  
  @override
  void initState() {
    super.initState();
    loadDueCards();
  }
  
  Future<void> loadDueCards() async {
    final cards = await studyService.getDueCards();
    setState(() {
      dueCards = cards;
    });
  }
  
  Future<void> handleRating(Rating rating) async {
    if (currentIndex >= dueCards.length) return;
    
    final card = dueCards[currentIndex];
    final result = await studyService.reviewCard(card, rating);
    
    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Next review: ${formatInterval(result.interval)}'),
        duration: Duration(seconds: 2),
      ),
    );
    
    // Move to next card
    setState(() {
      currentIndex++;
      showAnswer = false;
    });
    
    // Reload if we're done
    if (currentIndex >= dueCards.length) {
      await loadDueCards();
      setState(() {
        currentIndex = 0;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (dueCards.isEmpty) {
      return Center(
        child: Text('No cards due! Come back later.'),
      );
    }
    
    if (currentIndex >= dueCards.length) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Session complete!'),
            ElevatedButton(
              onPressed: () => loadDueCards(),
              child: Text('Check for more cards'),
            ),
          ],
        ),
      );
    }
    
    final card = dueCards[currentIndex];
    final progress = '${currentIndex + 1} / ${dueCards.length}';
    
    return Column(
      children: [
        // Progress indicator
        Padding(
          padding: EdgeInsets.all(16),
          child: Text(progress, style: TextStyle(fontSize: 18)),
        ),
        
        // Card display
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                showAnswer = !showAnswer;
              });
            },
            child: Card(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    showAnswer ? card.back : card.front,
                    style: TextStyle(fontSize: 24),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ),
        
        // Rating buttons (only show after revealing answer)
        if (showAnswer)
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildRatingButton('Again', Colors.red, Rating.again),
                _buildRatingButton('Hard', Colors.orange, Rating.hard),
                _buildRatingButton('Good', Colors.green, Rating.good),
                _buildRatingButton('Easy', Colors.blue, Rating.easy),
              ],
            ),
          ),
      ],
    );
  }
  
  Widget _buildRatingButton(String label, Color color, Rating rating) {
    return ElevatedButton(
      onPressed: () => handleRating(rating),
      style: ElevatedButton.styleFrom(backgroundColor: color),
      child: Text(label),
    );
  }
  
  String formatInterval(Duration interval) {
    if (interval.inDays > 0) {
      return '${interval.inDays} day${interval.inDays != 1 ? 's' : ''}';
    } else if (interval.inHours > 0) {
      return '${interval.inHours} hour${interval.inHours != 1 ? 's' : ''}';
    } else {
      return '${interval.inMinutes} minute${interval.inMinutes != 1 ? 's' : ''}';
    }
  }
}
```

---

## Database Schema

### SQLite Schema

```sql
-- Flashcards table
CREATE TABLE flashcards (
  cardId INTEGER PRIMARY KEY,
  front TEXT NOT NULL,
  back TEXT NOT NULL,
  state INTEGER NOT NULL,           -- 1=learning, 2=review, 3=relearning
  step INTEGER,
  stability REAL,
  difficulty REAL,
  due TEXT NOT NULL,                -- ISO8601 datetime
  lastReview TEXT,                  -- ISO8601 datetime
  createdAt TEXT NOT NULL,          -- ISO8601 datetime
  totalReviews INTEGER DEFAULT 0,
  deckId TEXT
);

-- Index for efficient queries
CREATE INDEX idx_due ON flashcards(due);
CREATE INDEX idx_deck ON flashcards(deckId);

-- Review logs table (for analytics)
CREATE TABLE review_logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  cardId INTEGER NOT NULL,
  rating INTEGER NOT NULL,          -- 1=again, 2=hard, 3=good, 4=easy
  reviewDateTime TEXT NOT NULL,     -- ISO8601 datetime
  reviewDuration INTEGER,           -- milliseconds
  FOREIGN KEY (cardId) REFERENCES flashcards(cardId)
);

CREATE INDEX idx_review_card ON review_logs(cardId);
CREATE INDEX idx_review_date ON review_logs(reviewDateTime);
```

### Firebase/Firestore Schema

```dart
// Collection: flashcards
{
  "cardId": 1234567890,
  "userId": "user_abc123",
  "front": "What is the capital of France?",
  "back": "Paris",
  "state": 2,
  "step": null,
  "stability": 45.3,
  "difficulty": 5.2,
  "due": "2024-02-15T10:30:00Z",
  "lastReview": "2024-01-01T08:00:00Z",
  "createdAt": "2023-12-01T12:00:00Z",
  "totalReviews": 12,
  "deckId": "deck_xyz789"
}

// Collection: reviewLogs
{
  "cardId": 1234567890,
  "userId": "user_abc123",
  "rating": 3,
  "reviewDateTime": "2024-01-01T08:00:00Z",
  "reviewDuration": 3500
}
```

---

## Explaining to Your Team

### The Simple Explanation (2 minutes)

**"FSRS is like a smart reminder system for flashcards."**

1. **User creates a card** → FSRS marks it as "due now"
2. **User reviews it** → FSRS learns how hard that card is for them
3. **User rates it** (Again/Hard/Good/Easy) → FSRS calculates when to show it next
4. **Repeat** → Cards get scheduled based on how well you know them

**Key insight:** Easy cards appear less often, hard cards appear more often.

### The Technical Explanation (5 minutes)

**FSRS tracks two numbers for each card:**
- **Stability**: How many days until you'll probably forget it (memory strength)
- **Difficulty**: How inherently hard the card is (1-10 scale)

**When you review a card:**
1. FSRS calculates your current "retrievability" (probability you remember it)
2. Based on your rating, it updates stability and difficulty
3. It calculates the optimal next review date using a forgetting curve formula
4. The card gets scheduled for that date

**Why it's better than simple algorithms:**
- It adapts to each individual card's difficulty
- It considers how long it's been since you last reviewed
- It uses ML-optimized parameters trained on millions of reviews
- It's more efficient than older algorithms like SM-2 (Anki's default)

### Key Benefits to Highlight

1. **For Users:**
   - Learn faster with less time studying
   - Cards appear at the perfect time (not too soon, not too late)
   - The algorithm adapts to their personal learning patterns

2. **For Developers:**
   - Well-tested, proven algorithm (used by thousands)
   - Simple to integrate (just 5 fields per card)
   - Handles edge cases automatically
   - Open source and well-documented

3. **For the Product:**
   - Competitive advantage (better than most flashcard apps)
   - Increases user retention (effective learning keeps users coming back)
   - Analytics-friendly (rich review log data)

### Common Questions from Team

**Q: "Why not use a simpler algorithm?"**
A: Simple algorithms (like "show it in 1 day, then 3 days, then 7 days") don't adapt to individual cards or users. FSRS is proven to be 20-30% more efficient.

**Q: "Is it hard to implement?"**
A: No! You just need to store 6 extra fields per card and call two functions: `reviewCard()` when they review, and query cards where `due <= now`.

**Q: "What if users have existing cards?"**
A: Existing cards can be migrated. Set them all to `state: learning` with null stability/difficulty, and FSRS will learn them on first review.

**Q: "Can we customize it?"**
A: Yes! You can adjust:
- Desired retention rate (how hard you want it to be)
- Learning steps (how quickly new cards graduate)
- Maximum interval (cap on how far out cards can be scheduled)

**Q: "What about syncing across devices?"**
A: The FSRS data is just 6 fields per card. Sync them like any other data. The algorithm is deterministic (same inputs = same outputs).

---

## Common Pitfalls

### 1. **Not Using UTC Dates**
```dart
// ❌ WRONG
reviewDateTime: DateTime.now()

// ✅ CORRECT
reviewDateTime: DateTime.now().toUtc()
```

### 2. **Forgetting to Copy the Card**
The `reviewCard()` function expects you to pass in a card, but it doesn't modify the original. Make sure to use the returned card.

```dart
// ❌ WRONG
scheduler.reviewCard(card, rating);
// card is unchanged!

// ✅ CORRECT
final result = scheduler.reviewCard(card, rating);
card = result.card;  // Use the returned card
```

### 3. **Not Handling New Cards**
New cards should have `state: State.learning` and `step: 0`, but null stability/difficulty. Don't set them to 0!

```dart
// ✅ CORRECT for new cards
Card(
  cardId: id,
  state: State.learning,
  step: 0,
  stability: null,  // NOT 0!
  difficulty: null, // NOT 0!
  due: DateTime.now().toUtc(),
  lastReview: null,
)
```

### 4. **Querying Due Cards Incorrectly**
Always use `<=` not `<` when querying due cards:

```dart
// ✅ CORRECT
WHERE due <= NOW()

// ❌ WRONG (misses cards due exactly now)
WHERE due < NOW()
```

### 5. **Not Validating Parameters**
If you allow custom scheduler parameters, validate them:

```dart
// The Scheduler constructor validates automatically, but catch errors:
try {
  final scheduler = Scheduler(parameters: customParams);
} catch (e) {
  // Handle invalid parameters
  print('Invalid parameters: $e');
}
```

### 6. **Ignoring Review Logs**
Always save review logs! They're valuable for:
- User analytics
- Debugging scheduling issues
- Future algorithm improvements

### 7. **Not Handling Edge Cases**
- What if user changes timezone? (Use UTC everywhere)
- What if device clock is wrong? (Consider server timestamp)
- What if user reviews same card twice in a row? (Allow it, FSRS handles it)

---

## Testing Your Integration

### Unit Tests

```dart
void main() {
  test('New card should be scheduled immediately', () async {
    final card = await Card.create();
    expect(card.state, State.learning);
    expect(card.due.isBefore(DateTime.now().toUtc().add(Duration(seconds: 1))), true);
  });
  
  test('Reviewing with Good should increase stability', () {
    final scheduler = Scheduler();
    final card = Card(
      cardId: 1,
      state: State.learning,
      step: 0,
      due: DateTime.now().toUtc(),
    );
    
    final result1 = scheduler.reviewCard(card, Rating.good);
    final stability1 = result1.card.stability!;
    
    final result2 = scheduler.reviewCard(result1.card, Rating.good);
    final stability2 = result2.card.stability!;
    
    expect(stability2, greaterThan(stability1));
  });
  
  test('Cards should graduate from learning to review', () {
    final scheduler = Scheduler(
      learningSteps: [Duration(minutes: 1)],
    );
    
    var card = Card(
      cardId: 1,
      state: State.learning,
      step: 0,
      due: DateTime.now().toUtc(),
    );
    
    // First review (still in learning)
    var result = scheduler.reviewCard(card, Rating.good);
    expect(result.card.state, State.learning);
    
    // Second review (should graduate)
    result = scheduler.reviewCard(result.card, Rating.good);
    expect(result.card.state, State.review);
  });
}
```

### Integration Tests

```dart
void main() {
  testWidgets('User can review a card', (WidgetTester tester) async {
    // Create a test card
    final card = Flashcard(
      cardId: 1,
      front: 'Test Question',
      back: 'Test Answer',
      state: State.learning,
      step: 0,
      due: DateTime.now().toUtc(),
      createdAt: DateTime.now(),
    );
    
    // Build widget
    await tester.pumpWidget(
      MaterialApp(home: StudyScreen(cards: [card])),
    );
    
    // Verify front is shown
    expect(find.text('Test Question'), findsOneWidget);
    
    // Tap to reveal answer
    await tester.tap(find.byType(Card));
    await tester.pump();
    
    // Verify back is shown
    expect(find.text('Test Answer'), findsOneWidget);
    
    // Tap "Good" button
    await tester.tap(find.text('Good'));
    await tester.pump();
    
    // Verify card was reviewed (check for confirmation message)
    expect(find.textContaining('Next review:'), findsOneWidget);
  });
}
```

---

## Next Steps

1. **Start Simple**: Implement basic card creation and review first
2. **Add Persistence**: Store FSRS data in your database
3. **Build UI**: Create the study screen with rating buttons
4. **Add Analytics**: Track review logs for insights
5. **Optimize**: Add features like daily limits, custom decks, etc.

### Recommended Implementation Order

1. ✅ Add FSRS fields to your card model
2. ✅ Initialize scheduler on app start
3. ✅ Implement card review flow
4. ✅ Add database persistence
5. ✅ Create study session UI
6. ✅ Add statistics dashboard
7. ✅ Implement review logs
8. ✅ Add advanced features (custom parameters, deck-specific settings, etc.)

---

## Additional Resources

- **FSRS Paper**: Search for "FSRS: A Modern Spaced Repetition Algorithm"
- **Original Python Implementation**: https://github.com/open-spaced-repetition/fsrs4anki
- **Algorithm Explanation**: https://github.com/open-spaced-repetition/fsrs4anki/wiki
- **Community**: Reddit r/Anki has lots of FSRS discussion

---

## Quick Reference

### Required Fields Per Card
```
cardId, state, step, stability, difficulty, due, lastReview
```

### When to Query Due Cards
```
WHERE due <= NOW()
```

### When to Review
```
final result = scheduler.reviewCard(card, rating);
```

### States Flow
```
learning → review → (if forgotten) → relearning → review
```

### Ratings
```
Again (1) - Forgot the card
Hard (2)  - Barely remembered
Good (3)  - Remembered correctly
Easy (4)  - Remembered easily
```
