class Prompt {
  final String promptId;
  final String text;
  final String category;
  final String difficulty;
  final int ieltsPartNumber; // 1, 2, or 3
  final List<String> focusAreas;
  final List<String> tags;

  Prompt({
    required this.promptId,
    required this.text,
    required this.category,
    required this.difficulty,
    required this.ieltsPartNumber,
    required this.focusAreas,
    required this.tags,
  });

  factory Prompt.fromJson(Map<String, dynamic> json) {
    return Prompt(
      promptId: json['promptId'] as String,
      text: json['text'] as String,
      category: json['category'] as String,
      difficulty: json['difficulty'] as String,
      ieltsPartNumber: json['ieltsPartNumber'] as int? ?? 1,
      focusAreas: List<String>.from(json['focusAreas'] as List? ?? []),
      tags: List<String>.from(json['tags'] as List? ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'promptId': promptId,
      'text': text,
      'category': category,
      'difficulty': difficulty,
      'ieltsPartNumber': ieltsPartNumber,
      'focusAreas': focusAreas,
      'tags': tags,
    };
  }
}

// Comprehensive IELTS prompts database
class IELTSPrompts {
  // IELTS Part 1: Introduction and Interview (4-5 minutes)
  static final List<Prompt> part1Prompts = [
    // Personal Information
    Prompt(
      promptId: 'part1_001',
      text: 'Tell me about yourself and where you come from.',
      category: 'personal_information',
      difficulty: 'beginner',
      ieltsPartNumber: 1,
      focusAreas: ['fluency', 'introduction'],
      tags: ['baseline', 'introduction', 'personal'],
    ),
    Prompt(
      promptId: 'part1_002',
      text: 'What do you do? Do you work or are you a student?',
      category: 'work_study',
      difficulty: 'beginner',
      ieltsPartNumber: 1,
      focusAreas: ['present_tense', 'fluency'],
      tags: ['work', 'study', 'occupation'],
    ),
    Prompt(
      promptId: 'part1_003',
      text: 'Describe your hometown. What do you like about it?',
      category: 'hometown',
      difficulty: 'beginner',
      ieltsPartNumber: 1,
      focusAreas: ['descriptive_language', 'present_tense'],
      tags: ['hometown', 'places', 'description'],
    ),
    
    // Daily Life
    Prompt(
      promptId: 'part1_004',
      text: 'What do you usually do on weekends?',
      category: 'daily_life',
      difficulty: 'beginner',
      ieltsPartNumber: 1,
      focusAreas: ['present_tense', 'routine'],
      tags: ['weekend', 'leisure', 'activities'],
    ),
    Prompt(
      promptId: 'part1_005',
      text: 'Do you prefer to spend time alone or with friends? Why?',
      category: 'preferences',
      difficulty: 'beginner',
      ieltsPartNumber: 1,
      focusAreas: ['opinion', 'fluency'],
      tags: ['social', 'preferences', 'friends'],
    ),
    
    // Hobbies and Interests
    Prompt(
      promptId: 'part1_006',
      text: 'What are your hobbies? How often do you do them?',
      category: 'hobbies',
      difficulty: 'beginner',
      ieltsPartNumber: 1,
      focusAreas: ['present_tense', 'frequency'],
      tags: ['hobbies', 'interests', 'leisure'],
    ),
    Prompt(
      promptId: 'part1_007',
      text: 'Do you enjoy reading? What kind of books do you like?',
      category: 'hobbies',
      difficulty: 'beginner',
      ieltsPartNumber: 1,
      focusAreas: ['preferences', 'vocabulary'],
      tags: ['reading', 'books', 'literature'],
    ),
    Prompt(
      promptId: 'part1_008',
      text: 'Are you interested in sports? Which sports do you follow?',
      category: 'sports',
      difficulty: 'beginner',
      ieltsPartNumber: 1,
      focusAreas: ['present_tense', 'interests'],
      tags: ['sports', 'fitness', 'activities'],
    ),
    
    // Technology
    Prompt(
      promptId: 'part1_009',
      text: 'How often do you use the internet? What do you use it for?',
      category: 'technology',
      difficulty: 'beginner',
      ieltsPartNumber: 1,
      focusAreas: ['frequency', 'purpose'],
      tags: ['internet', 'technology', 'daily_life'],
    ),
    Prompt(
      promptId: 'part1_010',
      text: 'Do you prefer to communicate by phone or in person? Why?',
      category: 'communication',
      difficulty: 'beginner',
      ieltsPartNumber: 1,
      focusAreas: ['preferences', 'comparison'],
      tags: ['communication', 'technology', 'social'],
    ),
  ];

  // IELTS Part 2: Long Turn (3-4 minutes)
  static final List<Prompt> part2Prompts = [
    Prompt(
      promptId: 'part2_001',
      text: 'Describe a memorable journey you have taken. You should say:\n- Where you went\n- Who you went with\n- What you did there\n- And explain why it was memorable',
      category: 'travel',
      difficulty: 'intermediate',
      ieltsPartNumber: 2,
      focusAreas: ['past_tense', 'storytelling', 'organization'],
      tags: ['travel', 'memories', 'experiences'],
    ),
    Prompt(
      promptId: 'part2_002',
      text: 'Describe a person who has influenced you. You should say:\n- Who this person is\n- How you know them\n- What they have done to influence you\n- And explain why they are important to you',
      category: 'people',
      difficulty: 'intermediate',
      ieltsPartNumber: 2,
      focusAreas: ['descriptive_language', 'past_tense', 'explanation'],
      tags: ['people', 'influence', 'relationships'],
    ),
    Prompt(
      promptId: 'part2_003',
      text: 'Describe a skill you would like to learn. You should say:\n- What the skill is\n- Why you want to learn it\n- How you plan to learn it\n- And explain how it would benefit you',
      category: 'skills',
      difficulty: 'intermediate',
      ieltsPartNumber: 2,
      focusAreas: ['future_plans', 'explanation', 'vocabulary'],
      tags: ['skills', 'learning', 'goals'],
    ),
    Prompt(
      promptId: 'part2_004',
      text: 'Describe a book or film that made an impression on you. You should say:\n- What it was about\n- When you read/watched it\n- Why it impressed you\n- And explain what you learned from it',
      category: 'entertainment',
      difficulty: 'intermediate',
      ieltsPartNumber: 2,
      focusAreas: ['past_tense', 'description', 'reflection'],
      tags: ['books', 'films', 'entertainment', 'culture'],
    ),
    Prompt(
      promptId: 'part2_005',
      text: 'Describe a time when you helped someone. You should say:\n- Who you helped\n- What you did to help them\n- Why they needed help\n- And explain how you felt about helping them',
      category: 'experiences',
      difficulty: 'intermediate',
      ieltsPartNumber: 2,
      focusAreas: ['past_tense', 'storytelling', 'emotions'],
      tags: ['helping', 'kindness', 'experiences'],
    ),
    Prompt(
      promptId: 'part2_006',
      text: 'Describe a place you would like to visit. You should say:\n- Where it is\n- What you know about it\n- What you would do there\n- And explain why you want to visit this place',
      category: 'travel',
      difficulty: 'intermediate',
      ieltsPartNumber: 2,
      focusAreas: ['future_plans', 'description', 'explanation'],
      tags: ['travel', 'places', 'dreams'],
    ),
    Prompt(
      promptId: 'part2_007',
      text: 'Describe an important decision you made. You should say:\n- What the decision was\n- When you made it\n- What the consequences were\n- And explain why it was important',
      category: 'decisions',
      difficulty: 'intermediate',
      ieltsPartNumber: 2,
      focusAreas: ['past_tense', 'explanation', 'reflection'],
      tags: ['decisions', 'life_events', 'experiences'],
    ),
    Prompt(
      promptId: 'part2_008',
      text: 'Describe a festival or celebration in your country. You should say:\n- What it is\n- When it takes place\n- How people celebrate it\n- And explain why it is important',
      category: 'culture',
      difficulty: 'intermediate',
      ieltsPartNumber: 2,
      focusAreas: ['description', 'present_tense', 'culture'],
      tags: ['festivals', 'culture', 'traditions'],
    ),
  ];

  // IELTS Part 3: Discussion (4-5 minutes)
  static final List<Prompt> part3Prompts = [
    Prompt(
      promptId: 'part3_001',
      text: 'How has technology changed the way people communicate in recent years?',
      category: 'technology',
      difficulty: 'advanced',
      ieltsPartNumber: 3,
      focusAreas: ['analysis', 'comparison', 'complex_sentences'],
      tags: ['technology', 'communication', 'society'],
    ),
    Prompt(
      promptId: 'part3_002',
      text: 'What are the advantages and disadvantages of living in a big city?',
      category: 'urban_life',
      difficulty: 'advanced',
      ieltsPartNumber: 3,
      focusAreas: ['comparison', 'analysis', 'vocabulary'],
      tags: ['cities', 'lifestyle', 'comparison'],
    ),
    Prompt(
      promptId: 'part3_003',
      text: 'Do you think education systems should focus more on practical skills or academic knowledge? Why?',
      category: 'education',
      difficulty: 'advanced',
      ieltsPartNumber: 3,
      focusAreas: ['opinion', 'argumentation', 'complex_ideas'],
      tags: ['education', 'skills', 'debate'],
    ),
    Prompt(
      promptId: 'part3_004',
      text: 'How do you think climate change will affect future generations?',
      category: 'environment',
      difficulty: 'advanced',
      ieltsPartNumber: 3,
      focusAreas: ['future_prediction', 'analysis', 'vocabulary'],
      tags: ['environment', 'climate', 'future'],
    ),
    Prompt(
      promptId: 'part3_005',
      text: 'What role does social media play in modern society? Is it mostly positive or negative?',
      category: 'technology',
      difficulty: 'advanced',
      ieltsPartNumber: 3,
      focusAreas: ['analysis', 'opinion', 'balanced_argument'],
      tags: ['social_media', 'society', 'technology'],
    ),
    Prompt(
      promptId: 'part3_006',
      text: 'How important is it for people to maintain a work-life balance? What can be done to achieve this?',
      category: 'work_life',
      difficulty: 'advanced',
      ieltsPartNumber: 3,
      focusAreas: ['opinion', 'solutions', 'complex_sentences'],
      tags: ['work', 'lifestyle', 'balance'],
    ),
  ];

  // Get all prompts
  static List<Prompt> getAllPrompts() {
    return [...part1Prompts, ...part2Prompts, ...part3Prompts];
  }

  // Get prompts by IELTS part
  static List<Prompt> getPromptsByPart(int partNumber) {
    switch (partNumber) {
      case 1:
        return part1Prompts;
      case 2:
        return part2Prompts;
      case 3:
        return part3Prompts;
      default:
        return part1Prompts;
    }
  }

  // Get baseline prompt (always Part 1, first prompt)
  static Prompt getBaselinePrompt() {
    return part1Prompts.first;
  }

  // Get daily prompt based on date (rotates through all prompts)
  static Prompt getDailyPrompt({DateTime? date}) {
    final targetDate = date ?? DateTime.now();
    final allPrompts = getAllPrompts();
    
    // Use day of year to determine which prompt to show
    // This ensures same prompt shows for the entire day
    final dayOfYear = targetDate.difference(DateTime(targetDate.year, 1, 1)).inDays;
    final promptIndex = dayOfYear % allPrompts.length;
    
    return allPrompts[promptIndex];
  }

  // Get random prompt from specific part
  static Prompt getRandomPromptFromPart(int partNumber) {
    final prompts = getPromptsByPart(partNumber);
    prompts.shuffle();
    return prompts.first;
  }

  // Get prompts by difficulty
  static List<Prompt> getPromptsByDifficulty(String difficulty) {
    return getAllPrompts()
        .where((p) => p.difficulty == difficulty)
        .toList();
  }

  // Get prompts by category
  static List<Prompt> getPromptsByCategory(String category) {
    return getAllPrompts()
        .where((p) => p.category == category)
        .toList();
  }
}
