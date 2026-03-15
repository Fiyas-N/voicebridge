/// Lesson model and library — structured speaking curriculum A1→C2
class Lesson {
  final String id;
  final String cefrLevel; // A1, A2, B1, B2, C1, C2
  final String topic;
  final String description;
  final String emoji;
  final List<String> prompts;

  const Lesson({
    required this.id,
    required this.cefrLevel,
    required this.topic,
    required this.description,
    required this.emoji,
    required this.prompts,
  });
}

/// Full lesson curriculum — 30 lessons across A1→C2
class LessonLibrary {
  static const List<Lesson> lessons = [
    // ── A1 — Beginner ──────────────────────────────────────────────────────
    Lesson(
      id: 'a1_intro',
      cefrLevel: 'A1',
      topic: 'Introduce Yourself',
      description: 'Tell us your name, age, and where you are from.',
      emoji: '👋',
      prompts: [
        'Tell me your name and where you are from.',
        'How old are you? What do you do?',
        'Describe your hometown in a few sentences.',
      ],
    ),
    Lesson(
      id: 'a1_family',
      cefrLevel: 'A1',
      topic: 'My Family',
      description: 'Talk about your family members.',
      emoji: '👨‍👩‍👧',
      prompts: [
        'How many people are in your family?',
        'Describe one person in your family.',
        'What do your parents do for work?',
      ],
    ),
    Lesson(
      id: 'a1_daily',
      cefrLevel: 'A1',
      topic: 'Daily Routine',
      description: 'Describe what you do every day.',
      emoji: '🌅',
      prompts: [
        'What time do you wake up?',
        'What do you eat for breakfast?',
        'Describe your morning routine.',
      ],
    ),
    Lesson(
      id: 'a1_colors',
      cefrLevel: 'A1',
      topic: 'Colors & Objects',
      description: 'Describe things around you using colors.',
      emoji: '🎨',
      prompts: [
        'Describe the room you are sitting in right now.',
        'What color is your favourite thing in your house?',
        'Describe what you are wearing today.',
      ],
    ),
    Lesson(
      id: 'a1_food',
      cefrLevel: 'A1',
      topic: 'Food & Drink',
      description: 'Talk about foods and drinks you like.',
      emoji: '🍎',
      prompts: [
        'What is your favourite food? Why?',
        'Describe your favourite meal.',
        'What do you usually drink in the morning?',
      ],
    ),

    // ── A2 — Elementary ────────────────────────────────────────────────────
    Lesson(
      id: 'a2_hobbies',
      cefrLevel: 'A2',
      topic: 'Hobbies & Interests',
      description: 'Talk about things you enjoy doing.',
      emoji: '🎮',
      prompts: [
        'What do you like to do in your free time?',
        'Describe a hobby you have had for a long time.',
        'How often do you do your favourite hobby?',
      ],
    ),
    Lesson(
      id: 'a2_shopping',
      cefrLevel: 'A2',
      topic: 'Shopping',
      description: 'Describe shopping experiences.',
      emoji: '🛍️',
      prompts: [
        'Where do you usually go shopping?',
        'Describe the last thing you bought.',
        'Do you prefer online or in-store shopping? Why?',
      ],
    ),
    Lesson(
      id: 'a2_weather',
      cefrLevel: 'A2',
      topic: 'Weather & Seasons',
      description: 'Talk about weather and your favourite season.',
      emoji: '🌤️',
      prompts: [
        'What is the weather like today?',
        'What is your favourite season and why?',
        'Describe the weather in your country during winter.',
      ],
    ),
    Lesson(
      id: 'a2_transport',
      cefrLevel: 'A2',
      topic: 'Getting Around',
      description: 'Talk about transportation and travel.',
      emoji: '🚌',
      prompts: [
        'How do you get to school or work?',
        'Describe your daily commute.',
        'Have you ever taken a long journey? Describe it.',
      ],
    ),
    Lesson(
      id: 'a2_plans',
      cefrLevel: 'A2',
      topic: 'Weekend Plans',
      description: 'Talk about plans and arrangements.',
      emoji: '📅',
      prompts: [
        'What are you planning to do this weekend?',
        'Talk about a recent exciting thing you did.',
        'Describe a place you would like to visit.',
      ],
    ),

    // ── B1 — Intermediate ──────────────────────────────────────────────────
    Lesson(
      id: 'b1_work',
      cefrLevel: 'B1',
      topic: 'Work & Career',
      description: 'Discuss your job, career goals, and work life.',
      emoji: '💼',
      prompts: [
        'Describe your ideal job.',
        'What skills are important in your field?',
        'How do you handle stress at work or school?',
      ],
    ),
    Lesson(
      id: 'b1_travel',
      cefrLevel: 'B1',
      topic: 'Travel Experiences',
      description: 'Talk about travel and different cultures.',
      emoji: '✈️',
      prompts: [
        'Describe the most interesting place you have visited.',
        'How do you prepare for a trip?',
        'Compare travelling abroad to travelling in your own country.',
      ],
    ),
    Lesson(
      id: 'b1_health',
      cefrLevel: 'B1',
      topic: 'Health & Lifestyle',
      description: 'Discuss health habits and healthy living.',
      emoji: '🏃',
      prompts: [
        'How do you stay healthy?',
        'What is one unhealthy habit you would like to change?',
        'Compare your current lifestyle to five years ago.',
      ],
    ),
    Lesson(
      id: 'b1_technology',
      cefrLevel: 'B1',
      topic: 'Technology in Daily Life',
      description: 'Talk about how technology affects your life.',
      emoji: '📱',
      prompts: [
        'How much time do you spend on your phone each day?',
        'Describe how technology has changed the way you work or study.',
        'What is the most useful technology in your life?',
      ],
    ),
    Lesson(
      id: 'b1_problems',
      cefrLevel: 'B1',
      topic: 'Problem Solving',
      description: 'Describe a problem and how you solved it.',
      emoji: '🔧',
      prompts: [
        'Describe a difficult situation you faced recently and how you solved it.',
        'Talk about a time when you had to make a difficult decision.',
        'How do you approach a problem you have never faced before?',
      ],
    ),

    // ── B2 — Upper Intermediate ────────────────────────────────────────────
    Lesson(
      id: 'b2_environment',
      cefrLevel: 'B2',
      topic: 'Environmental Issues',
      description: 'Discuss environmental problems and solutions.',
      emoji: '🌍',
      prompts: [
        'What do you think is the biggest environmental challenge today?',
        'Discuss the pros and cons of renewable energy.',
        'How can individuals help reduce climate change?',
      ],
    ),
    Lesson(
      id: 'b2_education',
      cefrLevel: 'B2',
      topic: 'Education Systems',
      description: 'Compare and discuss educational approaches.',
      emoji: '🎓',
      prompts: [
        'Compare the education system in your country to another country.',
        'Do you think university education is necessary for success?',
        'Discuss the advantages and disadvantages of online learning.',
      ],
    ),
    Lesson(
      id: 'b2_media',
      cefrLevel: 'B2',
      topic: 'Media & Influence',
      description: 'Analyse the role and impact of media.',
      emoji: '📺',
      prompts: [
        'How much do social media platforms influence public opinion?',
        'Discuss the advantages and disadvantages of 24-hour news.',
        'Should there be limits on freedom of speech online?',
      ],
    ),
    Lesson(
      id: 'b2_globalisation',
      cefrLevel: 'B2',
      topic: 'Globalisation',
      description: 'Discuss the effects of globalisation.',
      emoji: '🌐',
      prompts: [
        'Describe the impact of globalisation on your country.',
        'Is globalisation more positive or negative for local cultures?',
        'How has globalisation changed the job market?',
      ],
    ),
    Lesson(
      id: 'b2_abstract',
      cefrLevel: 'B2',
      topic: 'Abstract Ideas',
      description: 'Express and defend abstract opinions.',
      emoji: '💡',
      prompts: [
        'What does success mean to you?',
        'Is happiness a choice or a result of circumstances?',
        'Discuss the concept of work-life balance.',
      ],
    ),

    // ── C1 — Advanced ──────────────────────────────────────────────────────
    Lesson(
      id: 'c1_ethics',
      cefrLevel: 'C1',
      topic: 'Ethics & Society',
      description: 'Discuss complex ethical issues.',
      emoji: '⚖️',
      prompts: [
        'Is it ever justified to break the law for a moral reason?',
        'Discuss the ethical implications of artificial intelligence.',
        'How should societies balance individual freedoms with collective responsibility?',
      ],
    ),
    Lesson(
      id: 'c1_economics',
      cefrLevel: 'C1',
      topic: 'Economics & Inequality',
      description: 'Analyse economic systems and inequality.',
      emoji: '📊',
      prompts: [
        'What are the main causes of economic inequality in society?',
        'Discuss the pros and cons of a universal basic income.',
        'How can governments balance economic growth with social welfare?',
      ],
    ),
    Lesson(
      id: 'c1_psychology',
      cefrLevel: 'C1',
      topic: 'Psychology & Behaviour',
      description: 'Discuss human psychology and behaviour.',
      emoji: '🧠',
      prompts: [
        'How do early childhood experiences shape adult personality?',
        'Discuss the psychology of motivation and procrastination.',
        'To what extent is human behaviour determined by nature vs nurture?',
      ],
    ),
    Lesson(
      id: 'c1_science',
      cefrLevel: 'C1',
      topic: 'Science & Innovation',
      description: 'Discuss scientific discoveries and their impacts.',
      emoji: '🔬',
      prompts: [
        'What do you consider the most important scientific discovery of the 20th century?',
        'Discuss the potential risks and benefits of genetic engineering.',
        'Should space exploration be a priority given current global challenges?',
      ],
    ),
    Lesson(
      id: 'c1_debate',
      cefrLevel: 'C1',
      topic: 'Complex Debate',
      description: 'Present and defend a nuanced position.',
      emoji: '🎙️',
      prompts: [
        'Argue for or against: "Governments should have the power to restrict internet access."',
        'Discuss whether tradition should be preserved in a rapidly changing world.',
        'Critically assess the idea that technology makes us more isolated.',
      ],
    ),

    // ── C2 — Mastery ───────────────────────────────────────────────────────
    Lesson(
      id: 'c2_philosophy',
      cefrLevel: 'C2',
      topic: 'Philosophy & Ideas',
      description: 'Explore abstract philosophical questions.',
      emoji: '🦁',
      prompts: [
        'Does free will exist, or are our choices predetermined?',
        'Can morality exist without religion?',
        'Is it possible to achieve a truly just and equal society?',
      ],
    ),
    Lesson(
      id: 'c2_rhetoric',
      cefrLevel: 'C2',
      topic: 'Persuasion & Rhetoric',
      description: 'Master the art of compelling argumentation.',
      emoji: '🎯',
      prompts: [
        'Argue persuasively for an unpopular opinion of your choice.',
        'Deliver a two-minute speech to inspire a group of people.',
        'Refute the following: "Social media does more harm than good."',
      ],
    ),
    Lesson(
      id: 'c2_literature',
      cefrLevel: 'C2',
      topic: 'Literature & Culture',
      description: 'Analyse and discuss literary and cultural themes.',
      emoji: '📖',
      prompts: [
        'Analyse the role of storytelling in human civilisation.',
        'Discuss how literature reflects and shapes cultural values.',
        'Compare two works of literature from different cultures.',
      ],
    ),
    Lesson(
      id: 'c2_language',
      cefrLevel: 'C2',
      topic: 'Language & Communication',
      description: 'Reflect on language as a system and tool.',
      emoji: '🗣️',
      prompts: [
        'Discuss how language shapes our perception of reality.',
        'Is it possible to fully understand a culture without speaking its language?',
        'Analyse the role of metaphor in human communication.',
      ],
    ),
    Lesson(
      id: 'c2_synthesis',
      cefrLevel: 'C2',
      topic: 'Cross-Topic Synthesis',
      description: 'Connect ideas across multiple complex domains.',
      emoji: '🌟',
      prompts: [
        'How do economics, psychology, and politics intersect in shaping public health policy?',
        'Discuss the relationship between technological advancement and human happiness.',
        'Analyse the long-term societal impact of mass migration.',
      ],
    ),
  ];

  /// Get all lessons for a CEFR level
  static List<Lesson> forLevel(String cefr) =>
      lessons.where((l) => l.cefrLevel == cefr).toList();

  /// Get a lesson by ID
  static Lesson? byId(String id) =>
      lessons.where((l) => l.id == id).firstOrNull;

  /// Ordered CEFR levels
  static const List<String> levels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
}
