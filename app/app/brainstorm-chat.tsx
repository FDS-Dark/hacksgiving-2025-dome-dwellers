import React, { useState, useRef, useEffect } from 'react';
import { View, Text, TextInput, TouchableOpacity, ScrollView, StyleSheet, Animated } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Palette } from '@/constants/theme';
import { useRouter } from 'expo-router';
import { API_BASE_URL } from '@/constants/config';

interface Message {
  id: string;
  text: string;
  isUser: boolean;
  timestamp: Date;
}

type MoodType = 'Critical' | 'Creative' | 'Optimistic' | 'Pirate';

export default function BrainstormChat() {
  const [messages, setMessages] = useState<Message[]>([]);
  const [inputText, setInputText] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [selectedMood, setSelectedMood] = useState<MoodType>('Creative');
  const [moodSelected, setMoodSelected] = useState(false);
  const [isAnimatingOut, setIsAnimatingOut] = useState(false);
  const [showSuggestions, setShowSuggestions] = useState(true);

  const router = useRouter();
  
  const fadeAnim = useRef(new Animated.Value(1)).current;
  const scrollViewRef = React.useRef<ScrollView>(null);
  
  const messageSuggestions = [
    "What are common features that other Botanical gardens have that the Mitchell Domes do not?",
    "What makes the Mitchell Park Domes unique compared to other botanical gardens?",
    "How can the Domes improve their visitor experience?",
    "What are the most popular exhibits across botanical gardens?"
  ];
  
  const sendMessage = async () => {
    if (!inputText.trim()) return;

    const userMessage: Message = {
      id: Date.now().toString(),
      text: inputText,
      isUser: true,
      timestamp: new Date(),
    };

    setMessages(prev => [...prev, userMessage]);
    setInputText('');
    setShowSuggestions(false);
    setIsLoading(true);


    const ENDPOINT = `${API_BASE_URL}/chat/response`;
    try {
      const response = await fetch(ENDPOINT, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message: inputText,
          mood: selectedMood,
        }),
      });

      const data = await response.json();

      if (Math.floor(response.status / 100) == 4) {
        const msg = 'Sorry, I could not process your request. Error connecting to ' + ENDPOINT + " (" + response.status + ")";
      }
      if (Math.floor(response.status / 100) == 5) {
        const msg = 'Sorry, I could not process your request. Server error at ' + ENDPOINT + " (" + response.status + ")";
      }

      const botMessage: Message = {
        id: (Date.now() + 1).toString(),
        text: data.response,
        isUser: false,
        timestamp: new Date(),
      };

      setMessages(prev => [...prev, botMessage]);
    } catch (error) {
      console.error('Error sending message:', error);
      const errorMessage: Message = {
        id: (Date.now() + 1).toString(),
        text: 'Sorry, I could not process your request. Couldn\'t connect to ' + ENDPOINT,
        isUser: false,
        timestamp: new Date(),
      };
      setMessages(prev => [...prev, errorMessage]);
    } finally {
      setIsLoading(false);
      scrollViewRef.current?.scrollToEnd({ animated: true });
    }
  };

  const moods: MoodType[] = ['Critical', 'Creative', 'Optimistic'];

  const handleMoodSelection = (mood: MoodType) => {
    setSelectedMood(mood);
    setIsAnimatingOut(true);
    
    Animated.timing(fadeAnim, {
      toValue: 0,
      duration: 300,
      useNativeDriver: true,
    }).start(() => {
      setMoodSelected(true);
      setIsAnimatingOut(false);
    });
  };

  const handleSuggestionPress = (suggestion: string) => {
    setInputText(suggestion);
    setShowSuggestions(false);
  };

  return (
    <View style={styles.container}>
      <TouchableOpacity style={{position: 'absolute', top: 16, left: 16, zIndex: 10}} onPress={() => router.push('/')}>
        <Ionicons name="return-down-back" size={24} color={Palette.black}/>
      </TouchableOpacity>
      <Text style={styles.title}>Brainstorm Agent</Text>
      <Text style={styles.subtitle}>This chatbot has distilled information about 21 botanical gardens. Responses are AI generated.</Text>
      
      {/* Mood Selector - appears above chat until selection is made */}
      {(!moodSelected || isAnimatingOut) && (
        <Animated.View style={[styles.moodContainer, { opacity: fadeAnim }]}>
          <Text style={styles.moodLabel}>Choose your chat mood:</Text>
          <View style={styles.moodSelector}>
            {moods.map((mood) => (
              <TouchableOpacity
                key={mood}
                style={[
                  styles.moodButton,
                  selectedMood === mood && styles.selectedMoodButton,
                ]}
                onPress={() => handleMoodSelection(mood)}
                disabled={isAnimatingOut}
              >
                <Text
                  style={[
                    styles.moodButtonText,
                    selectedMood === mood && styles.selectedMoodButtonText,
                  ]}
                >
                  {mood}
                </Text>
              </TouchableOpacity>
            ))}
          </View>
        </Animated.View>
      )}
      
      <ScrollView style={styles.messagesContainer} ref={scrollViewRef}>
        {messages.map((message) => (
          <View
            key={message.id}
            style={[
              styles.messageItem,
              message.isUser ? styles.userMessage : styles.botMessage,
            ]}
          >
            <Text style={message.isUser ? styles.messageTextUser : styles.messageText}>{message.text}</Text>
            <Text style={message.isUser ? styles.timestampUser : styles.timestamp}>
              {message.timestamp.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' })}
            </Text>
          </View>
        ))}
        {isLoading && (
          <View style={[styles.messageItem, styles.botMessage]}>
            <Text style={styles.messageText}>Thinking...</Text>
          </View>
        )}
      </ScrollView>

      {/* Message Suggestions */}
      {showSuggestions && messages.length === 0 && (
        <View style={styles.suggestionsContainer}>
          <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.suggestionsScrollView}>
            {messageSuggestions.map((suggestion, index) => (
              <TouchableOpacity
                key={index}
                style={styles.suggestionBubble}
                onPress={() => handleSuggestionPress(suggestion)}
              >
                <Text style={styles.suggestionText}>{suggestion}</Text>
              </TouchableOpacity>
            ))}
          </ScrollView>
        </View>
      )}

      <View style={styles.inputContainer}>
        <TextInput
          style={styles.textInput}
          value={inputText}
          onChangeText={setInputText}
          placeholder="Type your message..."
          multiline
          onSubmitEditing={sendMessage}
        />
        <TouchableOpacity
          style={[styles.sendButton, isLoading && styles.disabledButton]}
          onPress={sendMessage}
          disabled={isLoading || !inputText.trim()}
        >
          <Text style={styles.sendButtonText}>Send</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    padding: 16,
    backgroundColor: '#f5f5f5',
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    textAlign: 'center',
    color: '#333',
  },
  subtitle: {
    fontSize: 12,
    textAlign: 'center',
    marginBottom: 16,
    color: '#666',
  },
  moodContainer: {
    marginBottom: 16,
    padding: 12,
    backgroundColor: '#fff',
    borderRadius: 8,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.1,
    shadowRadius: 2,
    elevation: 2,
  },
  moodLabel: {
    fontSize: 16,
    fontWeight: '600',
    color: '#333',
    marginBottom: 8,
  },
  moodSelector: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    gap: 8,
  },
  moodButton: {
    flex: 1,
    paddingVertical: 8,
    paddingHorizontal: 12,
    borderRadius: 6,
    borderWidth: 1,
    borderColor: 'rgb(5, 46, 22)',
    backgroundColor: '#fff',
    alignItems: 'center',
  },
  selectedMoodButton: {
    backgroundColor: 'rgb(5, 46, 22)',
  },
  moodButtonText: {
    fontSize: 14,
    fontWeight: '500',
    color: 'rgb(5, 46, 22)',
  },
  selectedMoodButtonText: {
    color: '#fff',
  },
  messagesContainer: {
    flex: 1,
    marginBottom: 16,
  },
  messageItem: {
    marginBottom: 12,
    padding: 12,
    borderRadius: 8,
    maxWidth: '90%',
  },
  userMessage: {
    backgroundColor: 'rgb(5, 46, 22)',
    alignSelf: 'flex-end',
  },
  botMessage: {
    backgroundColor: '#E5E5EA',
    alignSelf: 'flex-start',
  },
  messageText: {
    fontSize: 12,
    color: '#333',
  },
  messageTextUser: {
    fontSize: 12,
    color: '#FFF',
  },
  timestamp: {
    fontSize: 10,
    color: '#666',
    marginTop: 4,
  },
  timestampUser: {
    fontSize: 10,
    color: '#d8d8d8ff',
    marginTop: 4,
  },
  inputContainer: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    gap: 8,
  },
  textInput: {
    flex: 1,
    borderWidth: 1,
    borderColor: '#ddd',
    borderRadius: 8,
    padding: 12,
    backgroundColor: '#fff',
    maxHeight: 120,
  },
  sendButton: {
    backgroundColor: 'rgb(5, 46, 22)',
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderRadius: 8,
  },
  disabledButton: {
    backgroundColor: '#ccc',
  },
  sendButtonText: {
    color: '#fff',
    fontWeight: 'bold',
  },
  suggestionsContainer: {
    marginBottom: 12,
  },
  suggestionsScrollView: {
    maxHeight: 80,
  },
  suggestionBubble: {
    backgroundColor: '#f0f8f0',
    borderRadius: 20,
    paddingHorizontal: 16,
    paddingVertical: 8,
    marginRight: 8,
    borderWidth: 1,
    borderColor: 'rgba(5, 46, 22, 0.3)',
    maxWidth: 280,
  },
  suggestionText: {
    color: 'rgb(5, 46, 22)',
    fontSize: 13,
    lineHeight: 18,
  },
});