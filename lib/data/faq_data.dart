class FaqItem {
  final String question;
  final String answer;
  final String category;

  FaqItem({
    required this.question,
    required this.answer,
    required this.category,
  });
}

final List<FaqItem> faqData = [
  // General
  FaqItem(
    category: 'General',
    question: 'What is GymGuide?',
    answer: 'GymGuide is your ultimate personal fitness and nutrition companion. We use advanced algorithms and expert knowledge to provide tailored workout plans, meal guides, and tracking tools to help you achieve your health goals effectively.',
  ),
  FaqItem(
    category: 'General',
    question: 'Is GymGuide free to use?',
    answer: 'Yes! GymGuide offers a robust free version that includes basic workout tracking and our suite of health calculators. For those looking for a more personalized experience, our Premium plan offers AI-powered plan generation and advanced analytics.',
  ),
  FaqItem(
    category: 'General',
    question: 'Is GymGuide beginner friendly?',
    answer: 'Absolutely. We design our plans to be accessible for everyone from day-one beginners to advanced athletes. Every exercise comes with detailed instructions to ensure you perform them safely and effectively.',
  ),
  FaqItem(
    category: 'General',
    question: 'Can I use GymGuide on multiple devices?',
    answer: 'Yes, your GymGuide account syncs across all your devices. Simply log in with your credentials on any supported smartphone or tablet to access your data.',
  ),

  // Subscription
  FaqItem(
    category: 'Subscription',
    question: 'How do I cancel my subscription?',
    answer: 'Subscriptions are managed through the respective App Store (iOS) or Google Play Store (Android). You can cancel anytime by going to your device settings > Subscriptions and selecting GymGuide.',
  ),
  FaqItem(
    category: 'Subscription',
    question: 'What is included in the Premium plan?',
    answer: 'Premium users enjoy unlimited AI-generated workout and meal plans, detailed progress insights, personalized macro targets, and an ad-free experience across the entire platform.',
  ),
  FaqItem(
    category: 'Subscription',
    question: 'Can I get a refund?',
    answer: 'Refunds are handled by Apple or Google directly according to their refund policies. We recommend reaching out to their support teams for any billing-related inquiries.',
  ),

  // Workouts
  FaqItem(
    category: 'Workouts',
    question: 'Can I use GymGuide without equipment?',
    answer: 'Yes! When setting up your profile or generating a new plan, you can specify "Bodyweight Only" to receive a comprehensive routine that requires zero equipment.',
  ),
  FaqItem(
    category: 'Workouts',
    question: 'How often should I update my goals?',
    answer: 'We recommend reviewing your goals every 4-8 weeks. As your fitness levels improve or your body weight changes, updating your stats ensures your plans stay challenging and effective.',
  ),
  FaqItem(
    category: 'Workouts',
    question: 'Can I track my own custom exercises?',
    answer: 'Currently, you can track any of the hundreds of exercises in our verified database. We are working on a feature to allow completely custom exercise entries in a future update.',
  ),
  FaqItem(
    category: 'Workouts',
    question: 'Does GymGuide support home workouts?',
    answer: 'Yes, we have plans specifically designed for home environments, whether you have a full home gym or just a pair of dumbbells.',
  ),

  // Nutrition
  FaqItem(
    category: 'Nutrition',
    question: 'Does GymGuide create meal plans automatically?',
    answer: 'Our AI engine generates weekly meal plans based on your calorie needs, dietary preferences, and fitness goals to ensure you are fueling your body correctly.',
  ),
  FaqItem(
    category: 'Nutrition',
    question: 'Are the meal plans customizable?',
    answer: 'Yes, you can swap out meals, adjust portion sizes, and set dietary restrictions (like Vegan, Keto, or Gluten-Free) to make the plan work for your lifestyle.',
  ),
  FaqItem(
    category: 'Nutrition',
    question: 'How do I track my daily water intake?',
    answer: 'Inside the Progress or Meals tab, you can use our simple water tracker to log your intake throughout the day and stay hydrated.',
  ),

  // Calculators
  FaqItem(
    category: 'Calculators',
    question: 'How accurate are the calculators?',
    answer: 'Our calculators use scientifically validated formulas like the Mifflin-St Jeor equation and the U.S. Navy Body Fat formula. While they provide highly reliable estimates, they should be used as a guide rather than a clinical diagnosis.',
  ),
  FaqItem(
    category: 'Calculators',
    question: 'What formula do you use for BMI?',
    answer: 'We use the standard World Health Organization (WHO) formula: Weight (kg) / Height (m²). It is a universally accepted metric for assessing weight categories.',
  ),
  FaqItem(
    category: 'Calculators',
    question: 'How do I calculate my 1RM?',
    answer: 'Our 1RM Calculator uses the Epley formula, which estimates your peak strength based on the weight you lift and the number of reps you can complete for a specific exercise.',
  ),

  // Account & Privacy
  FaqItem(
    category: 'Account & Privacy',
    question: 'How do I delete my account?',
    answer: 'You can delete your account and all associated data by going to Profile > Settings > Delete Account. Please note that this action is permanent and cannot be undone.',
  ),
  FaqItem(
    category: 'Account & Privacy',
    question: 'Is my data safe with GymGuide?',
    answer: 'We take privacy seriously. Your data is encrypted and stored securely using industry-standard protocols. We never sell your personal health information to third parties.',
  ),
  FaqItem(
    category: 'Account & Privacy',
    question: 'How do I export my data?',
    answer: 'You can request a full export of your workout and health data in CSV format from the "Data Export" section in your account settings.',
  ),
];
