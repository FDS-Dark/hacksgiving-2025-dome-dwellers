import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  ActivityIndicator,
  SafeAreaView,
} from 'react-native';
import { Stack, useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Palette } from '@/constants/theme';
import { API_BASE_URL } from '@/constants/config';

interface FeedbackAnalytics {
  average_visit_rating: number | null;
  average_tropics_rating: number | null;
  average_desert_rating: number | null;
  average_show_rating: number | null;
  average_staff_rating: number | null;
  average_cleanliness_rating: number | null;
  total_feedback_count: number;
  comments: Array<{
    id: number;
    additional_comments: string | null;
    created_at: string;
  }>;
}

export default function BusinessAnalyticsScreen() {
  const router = useRouter();
  const [analytics, setAnalytics] = useState<FeedbackAnalytics | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    fetchAnalytics();
  }, []);

  const fetchAnalytics = async () => {
    try {
      setLoading(true);
      setError(null);
      const response = await fetch(`${API_BASE_URL}/feedback/analytics`);
      
      if (!response.ok) {
        throw new Error('Failed to fetch analytics');
      }
      
      const data = await response.json();
      setAnalytics(data);
    } catch (err) {
      console.error('Error fetching analytics:', err);
      setError(err instanceof Error ? err.message : 'Failed to load analytics');
    } finally {
      setLoading(false);
    }
  };

  const formatRating = (rating: number | null): string => {
    if (rating === null || rating === undefined) return 'N/A';
    return rating.toFixed(2);
  };

  const formatDate = (dateString: string): string => {
    const date = new Date(dateString);
    return date.toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
    });
  };

  const RatingCard = ({
    title,
    rating,
  }: {
    title: string;
    rating: number | null;
  }) => (
    <View style={styles.ratingCard}>
      <Text style={styles.ratingTitle}>{title}</Text>
      <View style={styles.ratingValueContainer}>
        <Text style={styles.ratingValue}>{formatRating(rating)}</Text>
        {rating !== null && (
          <View style={styles.starsContainer}>
            {[1, 2, 3, 4, 5].map((star) => (
              <Ionicons
                key={star}
                name={rating >= star ? 'star' : 'star-outline'}
                size={20}
                color={rating >= star ? '#FFD700' : Palette.gray900}
              />
            ))}
          </View>
        )}
      </View>
    </View>
  );

  return (
    <SafeAreaView style={styles.container}>
      <Stack.Screen
        options={{
          headerShown: true,
          title: 'Business Analytics',
          headerStyle: {
            backgroundColor: Palette.white,
          },
          headerTintColor: Palette.green900,
          headerTitleStyle: {
            fontWeight: '600',
          },
        }}
      />

      {loading ? (
        <View style={styles.loadingContainer}>
          <ActivityIndicator size="large" color={Palette.green900} />
          <Text style={styles.loadingText}>Loading analytics...</Text>
        </View>
      ) : error ? (
        <View style={styles.errorContainer}>
          <Ionicons name="alert-circle" size={48} color="#d32f2f" />
          <Text style={styles.errorText}>{error}</Text>
        </View>
      ) : analytics ? (
        <ScrollView style={styles.content} showsVerticalScrollIndicator={false}>
          {/* Summary Section */}
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Summary</Text>
            <View style={styles.summaryCard}>
              <Text style={styles.summaryLabel}>Total Feedback</Text>
              <Text style={styles.summaryValue}>{analytics.total_feedback_count}</Text>
            </View>
          </View>

          {/* Average Ratings Section */}
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Average Ratings</Text>
            <View style={styles.ratingsGrid}>
              <RatingCard
                title="Overall Visit"
                rating={analytics.average_visit_rating}
              />
              <RatingCard
                title="Tropics Dome"
                rating={analytics.average_tropics_rating}
              />
              <RatingCard
                title="Desert Dome"
                rating={analytics.average_desert_rating}
              />
              <RatingCard
                title="Show Dome"
                rating={analytics.average_show_rating}
              />
              <RatingCard
                title="Staff Friendliness"
                rating={analytics.average_staff_rating}
              />
              <RatingCard
                title="Cleanliness"
                rating={analytics.average_cleanliness_rating}
              />
            </View>
          </View>

          {/* Comments Section */}
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>
              User Comments ({analytics.comments.length})
            </Text>
            {analytics.comments.length === 0 ? (
              <View style={styles.emptyCommentsContainer}>
                <Ionicons name="chatbubble-outline" size={48} color={Palette.gray900} />
                <Text style={styles.emptyCommentsText}>No comments yet</Text>
              </View>
            ) : (
              <View style={styles.commentsContainer}>
                {analytics.comments.map((comment) => (
                  <View key={comment.id} style={styles.commentCard}>
                    <View style={styles.commentHeader}>
                      <Ionicons
                        name="person-circle-outline"
                        size={20}
                        color={Palette.green900}
                      />
                      <Text style={styles.commentDate}>
                        {formatDate(comment.created_at)}
                      </Text>
                    </View>
                    <Text style={styles.commentText}>
                      {comment.additional_comments}
                    </Text>
                  </View>
                ))}
              </View>
            )}
          </View>
        </ScrollView>
      ) : null}
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Palette.gray100,
  },
  content: {
    flex: 1,
    padding: 16,
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    gap: 12,
  },
  loadingText: {
    fontSize: 16,
    color: Palette.gray900,
  },
  errorContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    gap: 12,
    padding: 20,
  },
  errorText: {
    fontSize: 16,
    color: '#d32f2f',
    textAlign: 'center',
  },
  section: {
    marginBottom: 24,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: Palette.green900,
    marginBottom: 12,
  },
  summaryCard: {
    backgroundColor: Palette.white,
    borderRadius: 12,
    padding: 20,
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.05,
    shadowRadius: 2,
    elevation: 2,
  },
  summaryLabel: {
    fontSize: 14,
    color: Palette.gray900,
    marginBottom: 8,
  },
  summaryValue: {
    fontSize: 32,
    fontWeight: '700',
    color: Palette.green900,
  },
  ratingsGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 12,
  },
  ratingCard: {
    backgroundColor: Palette.white,
    borderRadius: 12,
    padding: 16,
    width: '48%',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.05,
    shadowRadius: 2,
    elevation: 2,
  },
  ratingTitle: {
    fontSize: 14,
    fontWeight: '600',
    color: Palette.green900,
    marginBottom: 8,
  },
  ratingValueContainer: {
    gap: 8,
  },
  ratingValue: {
    fontSize: 24,
    fontWeight: '700',
    color: Palette.green900,
  },
  starsContainer: {
    flexDirection: 'row',
    gap: 4,
  },
  commentsContainer: {
    gap: 12,
  },
  commentCard: {
    backgroundColor: Palette.white,
    borderRadius: 12,
    padding: 16,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.05,
    shadowRadius: 2,
    elevation: 2,
  },
  commentHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    marginBottom: 8,
  },
  commentDate: {
    fontSize: 12,
    color: Palette.gray900,
  },
  commentText: {
    fontSize: 14,
    color: Palette.black,
    lineHeight: 20,
  },
  emptyCommentsContainer: {
    backgroundColor: Palette.white,
    borderRadius: 12,
    padding: 40,
    alignItems: 'center',
    gap: 12,
  },
  emptyCommentsText: {
    fontSize: 14,
    color: Palette.gray900,
  },
});

