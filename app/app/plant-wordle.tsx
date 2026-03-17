import React, { useState, useEffect, useMemo } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, Modal } from 'react-native';
import { Stack, useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Palette } from '@/constants/theme';
import { usePlants } from '@/hooks/use-plants';

type LetterState = 'correct' | 'present' | 'absent' | 'empty';

interface Letter {
  letter: string;
  state: LetterState;
}

const MAX_GUESSES = 6;
const WORD_LENGTH = 5;

const FALLBACK_PLANTS = [
  'APPLE', 'BASIL', 'BEANS', 'BEECH', 'BIRCH', 'CEDAR', 'CACTI', 'CLOVE',
  'DAISY', 'ELDER', 'GINGER', 'GRAPE', 'GRASS', 'HEATH', 'HONEY',
  'LARCH', 'LAUREL', 'LEMON', 'LILAC', 'MAPLE', 'ONION', 'PALM',
  'PEACH', 'POPLAR', 'SPRUCE', 'THYME', 'TULIP', 'WALNUT', 'WILLOW'
];

export default function PlantWordleScreen() {
  const router = useRouter();
  const { data: plantsData, isLoading } = usePlants({ limit: 1000 });
  
  const fiveLetterPlants = useMemo(() => {
    const apiPlants: string[] = [];
    if (plantsData?.plants) {
      apiPlants.push(...plantsData.plants
        .map(plant => {
          const name = (plant.common_name || plant.scientific_name || '').toUpperCase().trim();
          return name.length === 5 && /^[A-Z]+$/.test(name) ? name : null;
        })
        .filter((name): name is string => name !== null)
        .filter((name, index, arr) => arr.indexOf(name) === index));
    }
    
    const allPlants = [...apiPlants, ...FALLBACK_PLANTS];
    return Array.from(new Set(allPlants));
  }, [plantsData]);

  const [targetWord, setTargetWord] = useState<string>('');
  const [guesses, setGuesses] = useState<Letter[][]>([]);
  const [currentGuess, setCurrentGuess] = useState<string>('');
  const [gameWon, setGameWon] = useState<boolean>(false);
  const [gameLost, setGameLost] = useState<boolean>(false);
  const [letterStates, setLetterStates] = useState<Record<string, LetterState>>({});

  useEffect(() => {
    if (fiveLetterPlants.length > 0 && !targetWord) {
      const randomIndex = Math.floor(Math.random() * fiveLetterPlants.length);
      setTargetWord(fiveLetterPlants[randomIndex]);
    }
  }, [fiveLetterPlants, targetWord]);

  const evaluateGuess = (guess: string): Letter[] => {
    const result: Letter[] = [];
    const targetArray = targetWord.split('');
    const guessArray = guess.split('');
    const targetLetterCounts: Record<string, number> = {};
    
    targetArray.forEach(letter => {
      targetLetterCounts[letter] = (targetLetterCounts[letter] || 0) + 1;
    });

    const usedIndices = new Set<number>();

    guessArray.forEach((letter, index) => {
      if (letter === targetArray[index]) {
        result.push({ letter, state: 'correct' });
        usedIndices.add(index);
        targetLetterCounts[letter]--;
      } else {
        result.push({ letter, state: 'absent' });
      }
    });

    guessArray.forEach((letter, index) => {
      if (result[index].state === 'correct') return;
      
      const foundIndex = targetArray.findIndex((targetLetter, i) => 
        targetLetter === letter && !usedIndices.has(i) && targetLetterCounts[letter] > 0
      );
      
      if (foundIndex !== -1) {
        result[index].state = 'present';
        usedIndices.add(foundIndex);
        targetLetterCounts[letter]--;
      }
    });

    return result;
  };

  const handleKeyPress = (key: string) => {
    if (gameWon || gameLost) return;

    if (key === 'ENTER') {
      if (currentGuess.length === WORD_LENGTH) {
        const upperGuess = currentGuess.toUpperCase();
        // Allow any 5-letter word, but only plant names can be the correct answer
        const evaluated = evaluateGuess(upperGuess);
        const newGuesses = [...guesses, evaluated];
        setGuesses(newGuesses);
        setCurrentGuess('');

        const newLetterStates = { ...letterStates };
        evaluated.forEach(({ letter, state }) => {
          if (!newLetterStates[letter] || state === 'correct' || 
              (state === 'present' && newLetterStates[letter] === 'absent')) {
            newLetterStates[letter] = state;
          }
        });
        setLetterStates(newLetterStates);

        if (upperGuess === targetWord) {
          setGameWon(true);
        } else if (newGuesses.length >= MAX_GUESSES) {
          setGameLost(true);
        }
      }
    } else if (key === 'BACKSPACE') {
      setCurrentGuess(prev => prev.slice(0, -1));
    } else if (currentGuess.length < WORD_LENGTH) {
      setCurrentGuess(prev => prev + key.toUpperCase());
    }
  };

  const handleNewGame = () => {
    if (fiveLetterPlants.length > 0) {
      const randomIndex = Math.floor(Math.random() * fiveLetterPlants.length);
      setTargetWord(fiveLetterPlants[randomIndex]);
      setGuesses([]);
      setCurrentGuess('');
      setGameWon(false);
      setGameLost(false);
      setLetterStates({});
    }
  };

  const keyboardRows = [
    ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
    ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'],
    ['ENTER', 'Z', 'X', 'C', 'V', 'B', 'N', 'M', 'BACKSPACE'],
  ];

  const getLetterBgColor = (state: LetterState) => {
    switch (state) {
      case 'correct': return '#10b981';
      case 'present': return '#f59e0b';
      case 'absent': return '#6b7280';
      default: return Palette.white;
    }
  };

  const getLetterTextColor = (state: LetterState) => {
    return state === 'empty' ? Palette.black : Palette.white;
  };

  if (isLoading) {
    return (
      <View style={styles.container}>
        <Stack.Screen
          options={{
            presentation: 'card',
            headerShown: true,
            title: 'Plant Wordle',
            headerLeft: () => (
              <TouchableOpacity onPress={() => router.back()}>
                <Ionicons name="arrow-back" size={24} color={Palette.green900} />
              </TouchableOpacity>
            ),
          }}
        />
        <View style={styles.loadingContainer}>
          <Text style={styles.loadingText}>Loading plants...</Text>
        </View>
      </View>
    );
  }

  if (fiveLetterPlants.length === 0) {
    return (
      <View style={styles.container}>
        <Stack.Screen
          options={{
            presentation: 'card',
            headerShown: true,
            title: 'Plant Wordle',
            headerLeft: () => (
              <TouchableOpacity onPress={() => router.back()}>
                <Ionicons name="arrow-back" size={24} color={Palette.green900} />
              </TouchableOpacity>
            ),
          }}
        />
        <View style={styles.loadingContainer}>
          <Text style={styles.errorText}>No 5-letter plant names found</Text>
        </View>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <Stack.Screen
        options={{
          presentation: 'card',
          headerShown: true,
          title: 'Plant Wordle',
          headerLeft: () => (
            <TouchableOpacity onPress={() => router.back()}>
              <Ionicons name="arrow-back" size={24} color={Palette.green900} />
            </TouchableOpacity>
          ),
        }}
      />

      <View style={styles.gameContainer}>
        <View style={styles.gridContainer}>
          {Array.from({ length: MAX_GUESSES }).map((_, rowIndex) => {
            const guess = guesses[rowIndex];
            const isCurrentRow = rowIndex === guesses.length;
            
            return (
              <View key={rowIndex} style={styles.row}>
                {Array.from({ length: WORD_LENGTH }).map((_, colIndex) => {
                  let letter: Letter;
                  if (guess) {
                    letter = guess[colIndex];
                  } else if (isCurrentRow && colIndex < currentGuess.length) {
                    letter = { letter: currentGuess[colIndex].toUpperCase(), state: 'empty' };
                  } else {
                    letter = { letter: '', state: 'empty' };
                  }

                  return (
                    <View
                      key={colIndex}
                      style={[
                        styles.letterBox,
                        { backgroundColor: getLetterBgColor(letter.state) },
                      ]}
                    >
                      <Text style={[styles.letterText, { color: getLetterTextColor(letter.state) }]}>
                        {letter.letter}
                      </Text>
                    </View>
                  );
                })}
              </View>
            );
          })}
        </View>

        <View style={styles.keyboardContainer}>
          {keyboardRows.map((row, rowIndex) => (
            <View key={rowIndex} style={styles.keyboardRow}>
              {row.map((key) => {
                const isSpecialKey = key === 'ENTER' || key === 'BACKSPACE';
                const keyState = letterStates[key] || 'empty';
                
                return (
                  <TouchableOpacity
                    key={key}
                    style={[
                      styles.keyButton,
                      isSpecialKey && styles.specialKey,
                      !isSpecialKey && keyState !== 'empty' && { backgroundColor: getLetterBgColor(keyState) },
                    ]}
                    onPress={() => handleKeyPress(key)}
                  >
                    {key === 'BACKSPACE' ? (
                      <Ionicons name="backspace" size={20} color={Palette.black} />
                    ) : (
                      <Text style={[
                        styles.keyText,
                        !isSpecialKey && keyState !== 'empty' && { color: Palette.white },
                      ]}>
                        {key}
                      </Text>
                    )}
                  </TouchableOpacity>
                );
              })}
            </View>
          ))}
        </View>
      </View>

      <Modal visible={gameWon || gameLost} transparent animationType="fade">
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <Ionicons 
              name={gameWon ? "trophy" : "close-circle"} 
              size={64} 
              color={gameWon ? '#10b981' : '#ef4444'} 
            />
            <Text style={styles.modalTitle}>
              {gameWon ? 'Congratulations!' : 'Game Over'}
            </Text>
            <Text style={styles.modalText}>
              {gameWon 
                ? `You guessed it in ${guesses.length} ${guesses.length === 1 ? 'try' : 'tries'}!`
                : `The plant was: ${targetWord}`
              }
            </Text>
            <TouchableOpacity style={styles.newGameButton} onPress={handleNewGame}>
              <Text style={styles.newGameButtonText}>New Game</Text>
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
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  loadingText: {
    fontSize: 18,
    color: Palette.green900,
  },
  errorText: {
    fontSize: 18,
    color: '#ef4444',
  },
  gameContainer: {
    flex: 1,
    padding: 20,
  },
  gridContainer: {
    alignItems: 'center',
    marginTop: 20,
    marginBottom: 30,
  },
  row: {
    flexDirection: 'row',
    marginBottom: 8,
    gap: 8,
  },
  letterBox: {
    width: 60,
    height: 60,
    borderWidth: 2,
    borderColor: Palette.gray200,
    borderRadius: 8,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: Palette.white,
  },
  letterText: {
    fontSize: 24,
    fontWeight: 'bold',
  },
  keyboardContainer: {
    gap: 8,
    paddingBottom: 20,
  },
  keyboardRow: {
    flexDirection: 'row',
    justifyContent: 'center',
    gap: 6,
  },
  keyButton: {
    minWidth: 32,
    height: 48,
    backgroundColor: Palette.gray200,
    borderRadius: 6,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: 8,
  },
  specialKey: {
    minWidth: 60,
    backgroundColor: Palette.gray900,
  },
  keyText: {
    fontSize: 14,
    fontWeight: '600',
    color: Palette.black,
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
  modalText: {
    fontSize: 16,
    color: Palette.gray900,
    textAlign: 'center',
    marginBottom: 20,
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
