/// SeedData.swift
///
/// Realistic seed data templates for testing the BuzzBox app
/// Contains pre-configured message templates with AI metadata
///
/// Created: 2025-10-25

import Foundation

/// Seed data templates for realistic test messages
struct SeedData {

    // MARK: - Message Templates

    /// FAQ question templates with expected AI metadata
    static let faqQuestions: [(text: String, faqMatchID: String, confidence: Double)] = [
        (
            "How do I change my profile picture?",
            "faq_profile_picture",
            0.92
        ),
        (
            "What's the best way to get your attention?",
            "faq_get_attention",
            0.88
        ),
        (
            "Can I share my social media with you?",
            "faq_share_social",
            0.85
        ),
        (
            "Do you have any upcoming live streams?",
            "faq_live_streams",
            0.90
        ),
        (
            "How often do you check your messages?",
            "faq_message_frequency",
            0.87
        ),
        (
            "What kind of content do you create?",
            "faq_content_type",
            0.91
        ),
        (
            "Can I suggest a topic for your next video?",
            "faq_suggest_topic",
            0.86
        )
    ]

    /// Business opportunity templates with opportunity scores
    static let businessMessages: [(text: String, score: Int)] = [
        (
            "Hi Andrew! I represent a brand that would love to collaborate with you. Are you open to sponsored content opportunities?",
            85
        ),
        (
            "Would you be interested in doing a paid partnership for our new product launch?",
            78
        ),
        (
            "We'd love to sponsor your next video. Can we schedule a call to discuss?",
            82
        ),
        (
            "I work for a tech company looking to partner with creators like you. Let's chat!",
            75
        ),
        (
            "Interested in affiliate marketing? We have a program that could be perfect for your audience.",
            70
        )
    ]

    /// Fan engagement templates (positive sentiment)
    static let fanEngagementMessages: [String] = [
        "Just wanted to say your content is amazing! Keep it up! 🔥",
        "Been following you for months, love everything you do!",
        "Your latest video really helped me out. Thank you!",
        "Huge fan here! Can't wait for your next post 😊",
        "You're seriously one of my favorite creators right now",
        "Love your energy and positivity! Keep doing what you do",
        "Your content always makes my day better",
        "Just recommended your channel to all my friends!",
        "Been binge-watching all your videos this week lol",
        "You inspire me to be more creative. Thank you!"
    ]

    /// Urgent messages (high intensity)
    static let urgentMessages: [String] = [
        "Hey, I need help with something urgent - are you available?",
        "Quick question - this is time-sensitive!",
        "URGENT: Issue with accessing the community, can you help?",
        "Need your advice ASAP on something important",
        "Time-sensitive question about your recent announcement"
    ]

    /// Casual questions (neutral sentiment)
    static let casualQuestions: [String] = [
        "What's your favorite tool for content creation?",
        "How did you get started with this?",
        "Do you have any tips for beginners?",
        "What's your daily routine like?",
        "What camera/mic setup do you use?",
        "How long have you been creating content?",
        "What inspires your content ideas?",
        "Do you have a team or do you work solo?"
    ]

    /// Spam messages (low-quality solicitations)
    static let spamMessages: [String] = [
        "Click here for FREE followers!!!",
        "Make $10,000/month working from home! DM for details",
        "You won a prize! Click this link now!",
        "Hey check out my profile for exclusive content 🔥",
        "Follow for follow? Let's grow together!",
        "Buy cheap followers and likes! Best prices!",
        "URGENT: Your account will be deleted unless you verify here",
        "Join my exclusive group for secret tips! Limited spots!"
    ]

    /// Negative sentiment fan messages (disappointed/frustrated)
    static let negativeFanMessages: [String] = [
        "Really disappointed with your recent content tbh",
        "I've been trying to reach you for weeks and no response...",
        "Not sure why you even bother with this community anymore",
        "Your latest video was pretty underwhelming compared to before",
        "Feeling ignored as a long-time supporter",
        "This isn't what I signed up for when I joined",
        "Starting to think you don't care about your real fans",
        "Expected better from someone with your experience"
    ]

    /// Creator responses (for creating back-and-forth conversations)
    static let creatorResponses: [String] = [
        "Thanks for reaching out! I'll get back to you soon 👍",
        "Great question! Let me think about that...",
        "I appreciate the support! Means a lot 🙏",
        "Hey! Yeah, I'm available to chat",
        "Thanks! I'm glad you enjoyed it",
        "That's a good idea, I'll consider it!",
        "Absolutely! Feel free to share your thoughts",
        "Working on some exciting stuff, stay tuned!",
        "Thanks for the feedback! Always helpful",
        "Let's discuss this further"
    ]

    // MARK: - AI Metadata Presets

    /// Generate AI metadata for FAQ messages
    static func faqMetadata(faqMatchID: String, confidence: Double) -> MessageMetadata {
        MessageMetadata(
            category: .fan,
            categoryConfidence: confidence,
            sentiment: .neutral,
            sentimentIntensity: .medium,
            opportunityScore: nil,
            faqMatchID: faqMatchID,
            faqConfidence: confidence
        )
    }

    /// Generate AI metadata for business messages
    static func businessMetadata(score: Int) -> MessageMetadata {
        MessageMetadata(
            category: .business,
            categoryConfidence: 0.88,
            sentiment: .positive,
            sentimentIntensity: .medium,
            opportunityScore: score,
            faqMatchID: nil,
            faqConfidence: nil
        )
    }

    /// Generate AI metadata for fan engagement messages
    static func fanMetadata() -> MessageMetadata {
        MessageMetadata(
            category: .fan,
            categoryConfidence: 0.92,
            sentiment: .positive,
            sentimentIntensity: .high,
            opportunityScore: nil,
            faqMatchID: nil,
            faqConfidence: nil
        )
    }

    /// Generate AI metadata for urgent messages
    static func urgentMetadata() -> MessageMetadata {
        MessageMetadata(
            category: .urgent,
            categoryConfidence: 0.85,
            sentiment: .urgent,
            sentimentIntensity: .high,
            opportunityScore: nil,
            faqMatchID: nil,
            faqConfidence: nil
        )
    }

    /// Generate AI metadata for neutral/casual messages
    static func neutralMetadata() -> MessageMetadata {
        MessageMetadata(
            category: .fan,
            categoryConfidence: 0.78,
            sentiment: .neutral,
            sentimentIntensity: .low,
            opportunityScore: nil,
            faqMatchID: nil,
            faqConfidence: nil
        )
    }

    /// Generate AI metadata for spam messages
    static func spamMetadata() -> MessageMetadata {
        MessageMetadata(
            category: .spam,
            categoryConfidence: 0.90,
            sentiment: .neutral,
            sentimentIntensity: .low,
            opportunityScore: nil,
            faqMatchID: nil,
            faqConfidence: nil
        )
    }

    /// Generate AI metadata for negative sentiment fan messages
    static func negativeFanMetadata() -> MessageMetadata {
        MessageMetadata(
            category: .fan,
            categoryConfidence: 0.85,
            sentiment: .negative,
            sentimentIntensity: .high,
            opportunityScore: nil,
            faqMatchID: nil,
            faqConfidence: nil
        )
    }
}

// MARK: - Supporting Types

/// Message metadata structure for AI processing
struct MessageMetadata {
    let category: MessageCategory
    let categoryConfidence: Double
    let sentiment: MessageSentiment
    let sentimentIntensity: SentimentIntensity
    let opportunityScore: Int?
    let faqMatchID: String?
    let faqConfidence: Double?
}

/// Template for a complete seeded message
struct SeedMessage {
    let text: String
    let senderID: String
    let timestamp: Date
    let metadata: MessageMetadata?

    init(text: String, senderID: String, timestamp: Date, metadata: MessageMetadata? = nil) {
        self.text = text
        self.senderID = senderID
        self.timestamp = timestamp
        self.metadata = metadata
    }
}
