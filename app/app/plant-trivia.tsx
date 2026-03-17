import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, ScrollView, Modal } from 'react-native';
import { Stack, useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Palette } from '@/constants/theme';

interface TriviaQuestion {
  question: string;
  options: string[];
  correctAnswer: number;
  explanation: string;
}

const TRIVIA_QUESTIONS: TriviaQuestion[] = [
  {
    question: "What is the process by which plants convert sunlight into energy?",
    options: ["Photosynthesis", "Respiration", "Transpiration", "Germination"],
    correctAnswer: 0,
    explanation: "Photosynthesis is the process by which plants use sunlight, water, and carbon dioxide to produce glucose and oxygen."
  },
  {
    question: "Which part of a plant is responsible for absorbing water and nutrients from the soil?",
    options: ["Leaves", "Stem", "Roots", "Flowers"],
    correctAnswer: 2,
    explanation: "Roots anchor the plant and absorb water and essential nutrients from the soil."
  },
  {
    question: "What gas do plants release during photosynthesis?",
    options: ["Carbon dioxide", "Nitrogen", "Oxygen", "Hydrogen"],
    correctAnswer: 2,
    explanation: "Plants release oxygen as a byproduct of photosynthesis, which is essential for most life on Earth."
  },
  {
    question: "Which plant is known as the 'Tree of Life'?",
    options: ["Oak", "Baobab", "Sequoia", "Palm"],
    correctAnswer: 1,
    explanation: "The Baobab tree is often called the 'Tree of Life' because it can store water in its trunk and provides food, water, and shelter."
  },
  {
    question: "What is the largest flower in the world?",
    options: ["Sunflower", "Rafflesia", "Titan Arum", "Lotus"],
    correctAnswer: 1,
    explanation: "The Rafflesia arnoldii produces the largest individual flower, which can grow up to 3 feet in diameter."
  },
  {
    question: "Which plant family includes tomatoes, potatoes, and peppers?",
    options: ["Rosaceae", "Solanaceae", "Fabaceae", "Lamiaceae"],
    correctAnswer: 1,
    explanation: "Solanaceae, also known as the nightshade family, includes tomatoes, potatoes, peppers, and eggplants."
  },
  {
    question: "What is the main pigment responsible for photosynthesis in plants?",
    options: ["Carotene", "Chlorophyll", "Anthocyanin", "Xanthophyll"],
    correctAnswer: 1,
    explanation: "Chlorophyll is the green pigment that captures light energy for photosynthesis."
  },
  {
    question: "Which desert plant can survive for years without water?",
    options: ["Cactus", "Aloe", "Yucca", "All of the above"],
    correctAnswer: 3,
    explanation: "Many desert plants, including cacti, aloe, and yucca, have adapted to survive long periods without water."
  },
  {
    question: "What is the scientific study of plants called?",
    options: ["Zoology", "Botany", "Ecology", "Biology"],
    correctAnswer: 1,
    explanation: "Botany is the scientific study of plants, including their physiology, structure, genetics, ecology, and distribution."
  },
  {
    question: "Which plant is the source of vanilla flavoring?",
    options: ["Vanilla orchid", "Vanilla bean", "Vanilla vine", "Vanilla shrub"],
    correctAnswer: 0,
    explanation: "Vanilla comes from the Vanilla orchid, specifically from the seed pods of Vanilla planifolia."
  },
  {
    question: "What is the oldest known living tree species?",
    options: ["Redwood", "Bristlecone Pine", "Yew", "Oak"],
    correctAnswer: 1,
    explanation: "Bristlecone pines are among the oldest living organisms, with some individuals over 5,000 years old."
  },
  {
    question: "Which process allows plants to lose water vapor through their leaves?",
    options: ["Photosynthesis", "Transpiration", "Respiration", "Germination"],
    correctAnswer: 1,
    explanation: "Transpiration is the process by which plants release water vapor through small openings called stomata in their leaves."
  },
  {
    question: "What type of plant reproduces using spores instead of seeds?",
    options: ["Ferns", "Conifers", "Flowering plants", "Grasses"],
    correctAnswer: 0,
    explanation: "Ferns reproduce using spores, which are different from seeds and don't contain an embryo."
  },
  {
    question: "Which plant is known for its ability to 'follow' the sun?",
    options: ["Sunflower", "Daisy", "Rose", "Tulip"],
    correctAnswer: 0,
    explanation: "Sunflowers exhibit heliotropism, turning their flower heads to follow the sun's movement across the sky."
  },
  {
    question: "What is the main function of a plant's stem?",
    options: ["Absorb water", "Produce food", "Support and transport", "Reproduction"],
    correctAnswer: 2,
    explanation: "Stems provide structural support and transport water, nutrients, and sugars between roots and leaves."
  },
  {
    question: "Which plant produces the world's most expensive spice?",
    options: ["Saffron", "Vanilla", "Cardamom", "Cinnamon"],
    correctAnswer: 0,
    explanation: "Saffron, derived from the Crocus sativus flower, is the world's most expensive spice by weight."
  },
  {
    question: "What is the tallest tree species in the world?",
    options: ["Giant Sequoia", "Coast Redwood", "Douglas Fir", "Eucalyptus"],
    correctAnswer: 1,
    explanation: "Coast Redwoods (Sequoia sempervirens) are the tallest trees, reaching heights over 350 feet."
  },
  {
    question: "Which plant is used to make chocolate?",
    options: ["Coffee bean", "Cacao tree", "Coconut palm", "Date palm"],
    correctAnswer: 1,
    explanation: "Chocolate comes from the seeds of the cacao tree (Theobroma cacao), native to Central and South America."
  },
  {
    question: "What are the tiny openings on plant leaves called?",
    options: ["Stomata", "Chloroplasts", "Veins", "Pores"],
    correctAnswer: 0,
    explanation: "Stomata are microscopic pores on leaf surfaces that allow gas exchange and water vapor release."
  },
  {
    question: "Which plant family includes roses, apples, and strawberries?",
    options: ["Rosaceae", "Fabaceae", "Lamiaceae", "Solanaceae"],
    correctAnswer: 0,
    explanation: "Rosaceae is the rose family, including many fruits like apples, strawberries, cherries, and ornamental roses."
  },
  {
    question: "What is the process of a seed sprouting called?",
    options: ["Pollination", "Germination", "Photosynthesis", "Fertilization"],
    correctAnswer: 1,
    explanation: "Germination is the process by which a seed begins to grow and develop into a new plant."
  },
  {
    question: "Which plant is known as the 'corpse flower'?",
    options: ["Rafflesia", "Titan Arum", "Venus Flytrap", "Pitcher Plant"],
    correctAnswer: 1,
    explanation: "Titan Arum (Amorphophallus titanum) is called the corpse flower due to its strong, unpleasant odor when blooming."
  },
  {
    question: "What do carnivorous plants primarily eat?",
    options: ["Small mammals", "Insects", "Fish", "Birds"],
    correctAnswer: 1,
    explanation: "Carnivorous plants like Venus flytraps and pitcher plants primarily catch and digest insects for nutrients."
  },
  {
    question: "Which tree produces acorns?",
    options: ["Maple", "Oak", "Pine", "Birch"],
    correctAnswer: 1,
    explanation: "Oak trees produce acorns, which are their fruit containing a single seed."
  },
  {
    question: "What is the main component of plant cell walls?",
    options: ["Chitin", "Cellulose", "Starch", "Protein"],
    correctAnswer: 1,
    explanation: "Cellulose is the primary structural component of plant cell walls, providing strength and rigidity."
  },
  {
    question: "Which plant is used to make paper?",
    options: ["Bamboo", "Pine", "Eucalyptus", "All of the above"],
    correctAnswer: 3,
    explanation: "Many plants are used for paper production, including trees like pine and eucalyptus, as well as bamboo."
  },
  {
    question: "What is the largest seed in the world?",
    options: ["Coconut", "Coco de mer", "Avocado", "Mango"],
    correctAnswer: 1,
    explanation: "The coco de mer (Lodoicea maldivica) produces the largest seed, weighing up to 30 kg."
  },
  {
    question: "Which plant is the source of aspirin?",
    options: ["Willow", "Birch", "Oak", "Maple"],
    correctAnswer: 0,
    explanation: "Aspirin's active ingredient, salicylic acid, was originally derived from willow tree bark."
  },
  {
    question: "What type of root system do grasses typically have?",
    options: ["Taproot", "Fibrous root", "Adventitious root", "Aerial root"],
    correctAnswer: 1,
    explanation: "Grasses have fibrous root systems with many thin roots spreading out horizontally near the soil surface."
  },
  {
    question: "Which plant is known for its ability to close its leaves when touched?",
    options: ["Venus Flytrap", "Mimosa", "Sensitive Plant", "Both Mimosa and Sensitive Plant"],
    correctAnswer: 3,
    explanation: "Both Mimosa pudica (Sensitive Plant) and other mimosa species exhibit thigmonasty, closing leaves when touched."
  },
  {
    question: "What is the primary purpose of flowers in plants?",
    options: ["Decoration", "Reproduction", "Water storage", "Food production"],
    correctAnswer: 1,
    explanation: "Flowers are the reproductive structures of flowering plants, facilitating pollination and seed production."
  },
  {
    question: "Which plant produces the spice cinnamon?",
    options: ["Cinnamon tree bark", "Cinnamon flower", "Cinnamon root", "Cinnamon seed"],
    correctAnswer: 0,
    explanation: "Cinnamon comes from the inner bark of several tree species from the genus Cinnamomum."
  },
  {
    question: "What is the study of tree rings called?",
    options: ["Dendrology", "Dendrochronology", "Phytology", "Arborology"],
    correctAnswer: 1,
    explanation: "Dendrochronology is the scientific method of dating tree rings to determine the age of trees and study past climate."
  },
  {
    question: "Which plant is the primary source of rubber?",
    options: ["Rubber tree", "Dandelion", "Milkweed", "Guayule"],
    correctAnswer: 0,
    explanation: "Natural rubber comes primarily from the latex of the rubber tree (Hevea brasiliensis)."
  },
  {
    question: "What are plants that live for more than two years called?",
    options: ["Annuals", "Biennials", "Perennials", "Ephemerals"],
    correctAnswer: 2,
    explanation: "Perennials are plants that live for more than two years, often flowering multiple times."
  },
  {
    question: "Which plant family includes mint, basil, and lavender?",
    options: ["Lamiaceae", "Rosaceae", "Fabaceae", "Asteraceae"],
    correctAnswer: 0,
    explanation: "Lamiaceae, also known as the mint family, includes many aromatic herbs like mint, basil, lavender, and sage."
  },
  {
    question: "What is the process of plants bending toward light called?",
    options: ["Phototropism", "Gravitropism", "Thigmotropism", "Hydrotropism"],
    correctAnswer: 0,
    explanation: "Phototropism is the growth response of plants toward or away from light sources."
  },
  {
    question: "Which plant is used to make tequila?",
    options: ["Agave", "Cactus", "Aloe", "Yucca"],
    correctAnswer: 0,
    explanation: "Tequila is made from the blue agave plant (Agave tequilana), specifically the heart of the plant."
  },
  {
    question: "What is the smallest flowering plant in the world?",
    options: ["Duckweed", "Watermeal", "Moss", "Algae"],
    correctAnswer: 1,
    explanation: "Watermeal (Wolffia) is the smallest flowering plant, with individual plants smaller than a grain of rice."
  },
  {
    question: "Which plant produces the fruit known as a 'drupe'?",
    options: ["Peach", "Apple", "Strawberry", "Banana"],
    correctAnswer: 0,
    explanation: "A drupe is a fruit with a single seed enclosed in a hard stone, like peaches, cherries, and olives."
  },
  {
    question: "What is the main difference between monocots and dicots?",
    options: ["Number of petals", "Number of seed leaves", "Root type", "Leaf shape"],
    correctAnswer: 1,
    explanation: "Monocots have one seed leaf (cotyledon), while dicots have two seed leaves."
  },
  {
    question: "Which plant is known for producing the largest leaves?",
    options: ["Giant Water Lily", "Banana", "Elephant Ear", "Rhubarb"],
    correctAnswer: 0,
    explanation: "The Giant Water Lily (Victoria amazonica) produces leaves that can reach 10 feet in diameter."
  },
  {
    question: "What is the process of transferring pollen from one flower to another called?",
    options: ["Fertilization", "Pollination", "Germination", "Propagation"],
    correctAnswer: 1,
    explanation: "Pollination is the transfer of pollen from the male part of a flower to the female part, enabling fertilization."
  },
  {
    question: "Which plant is the source of quinine, used to treat malaria?",
    options: ["Cinchona tree", "Willow", "Eucalyptus", "Neem"],
    correctAnswer: 0,
    explanation: "Quinine, an antimalarial drug, comes from the bark of the cinchona tree."
  },
  {
    question: "What are plants that grow on other plants without harming them called?",
    options: ["Parasites", "Epiphytes", "Saprophytes", "Carnivores"],
    correctAnswer: 1,
    explanation: "Epiphytes grow on other plants for support but don't derive nutrients from them, like many orchids and bromeliads."
  },
  {
    question: "Which plant produces the spice black pepper?",
    options: ["Pepper tree", "Pepper vine", "Pepper shrub", "Pepper grass"],
    correctAnswer: 1,
    explanation: "Black pepper comes from the fruit of Piper nigrum, a flowering vine native to India."
  },
  {
    question: "What is the waxy coating on plant leaves called?",
    options: ["Cuticle", "Epidermis", "Stomata", "Mesophyll"],
    correctAnswer: 0,
    explanation: "The cuticle is a waxy layer on the outer surface of leaves that helps prevent water loss."
  },
  {
    question: "Which plant family includes beans, peas, and peanuts?",
    options: ["Fabaceae", "Solanaceae", "Rosaceae", "Brassicaceae"],
    correctAnswer: 0,
    explanation: "Fabaceae, also known as the legume or pea family, includes beans, peas, peanuts, and many other important crops."
  },
  {
    question: "What is the process of a plant losing its leaves seasonally called?",
    options: ["Evergreen", "Deciduous", "Perennial", "Annual"],
    correctAnswer: 1,
    explanation: "Deciduous plants lose their leaves seasonally, typically in autumn, to conserve water during winter."
  },
  {
    question: "Which plant is used to make the spice turmeric?",
    options: ["Turmeric root", "Turmeric flower", "Turmeric seed", "Turmeric leaf"],
    correctAnswer: 0,
    explanation: "Turmeric comes from the rhizome (underground stem) of the Curcuma longa plant."
  },
  {
    question: "What is the study of algae called?",
    options: ["Phycology", "Mycology", "Bryology", "Pteridology"],
    correctAnswer: 0,
    explanation: "Phycology is the scientific study of algae, which are photosynthetic organisms found in water."
  },
  {
    question: "Which plant produces the largest fruit?",
    options: ["Watermelon", "Pumpkin", "Jackfruit", "Durian"],
    correctAnswer: 2,
    explanation: "Jackfruit (Artocarpus heterophyllus) produces the largest tree-borne fruit, weighing up to 55 kg."
  },
  {
    question: "What are the male reproductive parts of a flower called?",
    options: ["Pistils", "Stamens", "Petals", "Sepals"],
    correctAnswer: 1,
    explanation: "Stamens are the male reproductive parts of a flower, consisting of anthers (which produce pollen) and filaments."
  },
  {
    question: "Which plant is known for its ability to survive in extremely cold temperatures?",
    options: ["Arctic Willow", "Pine", "Spruce", "All of the above"],
    correctAnswer: 3,
    explanation: "Many plants have adapted to cold climates, including Arctic willow, pines, and spruces that can survive freezing temperatures."
  },
  {
    question: "What is the process of plants growing toward or away from gravity called?",
    options: ["Phototropism", "Gravitropism", "Thigmotropism", "Chemotropism"],
    correctAnswer: 1,
    explanation: "Gravitropism (or geotropism) is the growth response of plants to gravity, causing roots to grow downward and stems upward."
  },
];

export default function PlantTriviaScreen() {
  const router = useRouter();
  const [currentQuestionIndex, setCurrentQuestionIndex] = useState(0);
  const [selectedAnswer, setSelectedAnswer] = useState<number | null>(null);
  const [score, setScore] = useState(0);
  const [showExplanation, setShowExplanation] = useState(false);
  const [gameFinished, setGameFinished] = useState(false);
  const [questions, setQuestions] = useState<TriviaQuestion[]>(() => {
    const shuffled = [...TRIVIA_QUESTIONS].sort(() => Math.random() - 0.5);
    return shuffled.slice(0, 10);
  });

  const currentQuestion = questions[currentQuestionIndex];

  const handleAnswerSelect = (answerIndex: number) => {
    if (selectedAnswer !== null) return;
    
    setSelectedAnswer(answerIndex);
    setShowExplanation(true);
    
    if (answerIndex === currentQuestion.correctAnswer) {
      setScore(prev => prev + 1);
    }
  };

  const handleNext = () => {
    if (currentQuestionIndex < questions.length - 1) {
      setCurrentQuestionIndex(prev => prev + 1);
      setSelectedAnswer(null);
      setShowExplanation(false);
    } else {
      setGameFinished(true);
    }
  };

  const handleNewGame = () => {
    const shuffled = [...TRIVIA_QUESTIONS].sort(() => Math.random() - 0.5);
    setQuestions(shuffled.slice(0, 10));
    setCurrentQuestionIndex(0);
    setSelectedAnswer(null);
    setScore(0);
    setShowExplanation(false);
    setGameFinished(false);
  };

  const getAnswerStyle = (index: number) => {
    if (selectedAnswer === null) {
      return styles.answerButton;
    }
    
    if (index === currentQuestion.correctAnswer) {
      return [styles.answerButton, styles.correctAnswer];
    }
    
    if (index === selectedAnswer && index !== currentQuestion.correctAnswer) {
      return [styles.answerButton, styles.incorrectAnswer];
    }
    
    return [styles.answerButton, styles.disabledAnswer];
  };

  const getAnswerIcon = (index: number) => {
    if (selectedAnswer === null) return null;
    
    if (index === currentQuestion.correctAnswer) {
      return <Ionicons name="checkmark-circle" size={24} color={Palette.white} style={styles.answerIcon} />;
    }
    
    if (index === selectedAnswer && index !== currentQuestion.correctAnswer) {
      return <Ionicons name="close-circle" size={24} color={Palette.white} style={styles.answerIcon} />;
    }
    
    return null;
  };

  return (
    <View style={styles.container}>
      <Stack.Screen
        options={{
          presentation: 'card',
          headerShown: true,
          title: 'Plant Trivia',
          headerLeft: () => (
            <TouchableOpacity onPress={() => router.back()}>
              <Ionicons name="arrow-back" size={24} color={Palette.green900} />
            </TouchableOpacity>
          ),
        }}
      />

      <View style={styles.content}>
        <View style={styles.header}>
          <View style={styles.progressBar}>
            <View 
              style={[
                styles.progressFill, 
                { width: `${((currentQuestionIndex + 1) / questions.length) * 100}%` }
              ]} 
            />
          </View>
          <Text style={styles.progressText}>
            Question {currentQuestionIndex + 1} of {questions.length}
          </Text>
          <Text style={styles.scoreText}>Score: {score}/{questions.length}</Text>
        </View>

        <ScrollView style={styles.questionContainer} contentContainerStyle={styles.questionContent}>
          <Text style={styles.questionText}>{currentQuestion.question}</Text>
          
          <View style={styles.answersContainer}>
            {currentQuestion.options.map((option, index) => (
              <TouchableOpacity
                key={index}
                style={getAnswerStyle(index)}
                onPress={() => handleAnswerSelect(index)}
                disabled={selectedAnswer !== null}
              >
                <View style={styles.answerContent}>
                  {getAnswerIcon(index)}
                  <Text style={[
                    styles.answerText,
                    (selectedAnswer !== null && index === currentQuestion.correctAnswer) && styles.correctText,
                    (selectedAnswer !== null && index === selectedAnswer && index !== currentQuestion.correctAnswer) && styles.incorrectText,
                    (selectedAnswer !== null && index !== currentQuestion.correctAnswer && index !== selectedAnswer) && styles.disabledText,
                  ]}>
                    {option}
                  </Text>
                </View>
              </TouchableOpacity>
            ))}
          </View>

          {showExplanation && (
            <View style={styles.explanationContainer}>
              <View style={styles.explanationHeader}>
                <Ionicons 
                  name={selectedAnswer === currentQuestion.correctAnswer ? "checkmark-circle" : "information-circle"} 
                  size={24} 
                  color={selectedAnswer === currentQuestion.correctAnswer ? '#10b981' : '#f59e0b'} 
                />
                <Text style={styles.explanationTitle}>
                  {selectedAnswer === currentQuestion.correctAnswer ? 'Correct!' : 'Incorrect'}
                </Text>
              </View>
              <Text style={styles.explanationText}>{currentQuestion.explanation}</Text>
            </View>
          )}
        </ScrollView>

        {showExplanation && (
          <View style={styles.footer}>
            <TouchableOpacity style={styles.nextButton} onPress={handleNext}>
              <Text style={styles.nextButtonText}>
                {currentQuestionIndex < questions.length - 1 ? 'Next Question' : 'Finish'}
              </Text>
              <Ionicons name="arrow-forward" size={20} color={Palette.white} />
            </TouchableOpacity>
          </View>
        )}
      </View>

      <Modal visible={gameFinished} transparent animationType="fade">
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <Ionicons 
              name="trophy" 
              size={64} 
              color={score >= questions.length * 0.7 ? '#10b981' : score >= questions.length * 0.5 ? '#f59e0b' : '#ef4444'} 
            />
            <Text style={styles.modalTitle}>Quiz Complete!</Text>
            <Text style={styles.modalScore}>
              You scored {score} out of {questions.length}
            </Text>
            <Text style={styles.modalMessage}>
              {score === questions.length 
                ? "Perfect score! You're a plant expert! 🌱"
                : score >= questions.length * 0.7
                ? "Great job! You know your plants well! 🌿"
                : score >= questions.length * 0.5
                ? "Good effort! Keep learning about plants! 🌳"
                : "Keep practicing! Plants are fascinating! 🌺"
              }
            </Text>
            <TouchableOpacity style={styles.newGameButton} onPress={handleNewGame}>
              <Text style={styles.newGameButtonText}>Play Again</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#faf8f3',
  },
  content: {
    flex: 1,
    padding: 20,
  },
  header: {
    marginBottom: 20,
  },
  progressBar: {
    height: 8,
    backgroundColor: Palette.gray200,
    borderRadius: 4,
    marginBottom: 12,
    overflow: 'hidden',
  },
  progressFill: {
    height: '100%',
    backgroundColor: Palette.green900,
    borderRadius: 4,
  },
  progressText: {
    fontSize: 14,
    color: Palette.gray900,
    marginBottom: 4,
  },
  scoreText: {
    fontSize: 16,
    fontWeight: '600',
    color: Palette.green900,
  },
  questionContainer: {
    flex: 1,
  },
  questionContent: {
    paddingBottom: 20,
  },
  questionText: {
    fontSize: 22,
    fontWeight: 'bold',
    color: Palette.green900,
    marginBottom: 24,
    lineHeight: 32,
  },
  answersContainer: {
    gap: 12,
  },
  answerButton: {
    backgroundColor: Palette.white,
    borderRadius: 12,
    padding: 16,
    borderWidth: 2,
    borderColor: Palette.gray200,
    minHeight: 60,
    justifyContent: 'center',
  },
  correctAnswer: {
    backgroundColor: '#10b981',
    borderColor: '#10b981',
  },
  incorrectAnswer: {
    backgroundColor: '#ef4444',
    borderColor: '#ef4444',
  },
  disabledAnswer: {
    opacity: 0.6,
  },
  answerContent: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  answerIcon: {
    marginRight: 4,
  },
  answerText: {
    fontSize: 16,
    color: Palette.black,
    flex: 1,
  },
  correctText: {
    color: Palette.white,
    fontWeight: '600',
  },
  incorrectText: {
    color: Palette.white,
    fontWeight: '600',
  },
  disabledText: {
    color: Palette.gray900,
  },
  explanationContainer: {
    backgroundColor: Palette.white,
    borderRadius: 12,
    padding: 16,
    marginTop: 20,
    borderWidth: 2,
    borderColor: Palette.gray200,
  },
  explanationHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    marginBottom: 12,
  },
  explanationTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: Palette.green900,
  },
  explanationText: {
    fontSize: 15,
    color: Palette.gray900,
    lineHeight: 22,
  },
  footer: {
    paddingTop: 16,
    borderTopWidth: 1,
    borderTopColor: Palette.gray200,
  },
  nextButton: {
    backgroundColor: Palette.green900,
    borderRadius: 12,
    padding: 16,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
  },
  nextButtonText: {
    color: Palette.white,
    fontSize: 16,
    fontWeight: '600',
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  modalContent: {
    backgroundColor: Palette.white,
    borderRadius: 16,
    padding: 24,
    alignItems: 'center',
    minWidth: 300,
    maxWidth: '90%',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 8,
  },
  modalTitle: {
    fontSize: 24,
    fontWeight: 'bold',
    color: Palette.green900,
    marginTop: 16,
    marginBottom: 8,
  },
  modalScore: {
    fontSize: 20,
    fontWeight: '600',
    color: Palette.gray900,
    marginBottom: 12,
  },
  modalMessage: {
    fontSize: 16,
    color: Palette.gray900,
    textAlign: 'center',
    marginBottom: 20,
    lineHeight: 24,
  },
  newGameButton: {
    backgroundColor: Palette.green900,
    paddingHorizontal: 24,
    paddingVertical: 12,
    borderRadius: 8,
  },
  newGameButtonText: {
    color: Palette.white,
    fontSize: 16,
    fontWeight: '600',
  },
});
