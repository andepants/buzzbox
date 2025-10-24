/**
 * Seed Data Cloud Functions for QA Testing
 *
 * HTTP functions to populate Firestore with test data:
 * - seedFAQs: Creates 15 FAQs for Story 6.3
 * - seedCreatorProfile: Creates creator profile for Story 6.4
 *
 * Call these functions once after deployment to set up QA test data.
 */

import {onRequest} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";

/**
 * Seed 15 FAQs to Firestore
 * GET https://us-central1-buzzbox-ios.cloudfunctions.net/seedFAQs
 */
export const seedFAQs = onRequest({region: "us-central1"}, async (req, res) => {
  const db = admin.firestore();

  const faqs = [
    {
      id: "faq-001",
      question: "What time do you stream?",
      answer: "I stream Monday-Friday at 7pm EST on YouTube! See you there 🎮",
      category: "schedule",
      order: 1,
    },
    {
      id: "faq-002",
      question: "How can I support you?",
      answer: "Thanks for asking! You can support through YouTube memberships, " +
        "Patreon, or just sharing my content. Every bit helps! 🙏",
      category: "support",
      order: 2,
    },
    {
      id: "faq-003",
      question: "Do you take collaboration requests?",
      answer: "Absolutely! I'm always open to collaborations. Send me a DM with " +
        "details about your project and let's see if we're a good fit!",
      category: "collaboration",
      order: 3,
    },
    {
      id: "faq-004",
      question: "What's your tech stack?",
      answer: "I primarily work with Swift, SwiftUI, and Firebase for iOS " +
        "development. Also use TypeScript, Node.js, and React for web projects.",
      category: "technical",
      order: 4,
    },
    {
      id: "faq-005",
      question: "How do I submit content ideas?",
      answer: "Love getting suggestions! Just drop your idea in the #general " +
        "channel or DM me directly. I read all of them! 💡",
      category: "general",
      order: 5,
    },
    {
      id: "faq-006",
      question: "Where can I find your social media?",
      answer: "You can find me on YouTube (Andrew Heim Dev), Twitter " +
        "@andrewheimdev, and GitHub at github.com/andrewheim. Links in my profile!",
      category: "general",
      order: 6,
    },
    {
      id: "faq-007",
      question: "Do you offer consulting or coaching?",
      answer: "Yes! I offer 1-on-1 coaching for iOS development and app " +
        "architecture. DM me for rates and availability.",
      category: "collaboration",
      order: 7,
    },
    {
      id: "faq-008",
      question: "What camera and mic do you use?",
      answer: "I use a Sony A6400 camera and Shure SM7B microphone with a " +
        "Focusrite Scarlett 2i2 interface. Great setup for tutorials!",
      category: "technical",
      order: 8,
    },
    {
      id: "faq-009",
      question: "How did you get started in iOS development?",
      answer: "Started learning Swift in 2015, built a few side projects, then " +
        "landed my first iOS job. Been building apps and teaching ever since! 📱",
      category: "general",
      order: 9,
    },
    {
      id: "faq-010",
      question: "Can I use your code in my project?",
      answer: "Most of my open-source code is MIT licensed, so yes! Just check " +
        "the repo's LICENSE file. Always happy to see my code helping others! 👍",
      category: "technical",
      order: 10,
    },
    {
      id: "faq-011",
      question: "How often do you post content?",
      answer: "I aim for 2-3 videos per week on YouTube, plus daily updates on " +
        "Twitter. Join the Discord for behind-the-scenes content!",
      category: "schedule",
      order: 11,
    },
    {
      id: "faq-012",
      question: "Do you have a Discord server?",
      answer: "Not yet, but I'm using this BuzzBox app as my community hub! " +
        "Think of it as a private Discord just for my fans. 🚀",
      category: "general",
      order: 12,
    },
    {
      id: "faq-013",
      question: "What courses do you recommend for learning iOS?",
      answer: "I recommend starting with Apple's Swift documentation, then Paul " +
        "Hudson's Hacking with Swift. Practice is key - build projects!",
      category: "general",
      order: 13,
    },
    {
      id: "faq-014",
      question: "How do I report a bug in your app?",
      answer: "Great question! Just DM me with details: what happened, what you " +
        "expected, and screenshots if possible. I'll look into it ASAP!",
      category: "support",
      order: 14,
    },
    {
      id: "faq-015",
      question: "Do you do sponsored content?",
      answer: "I'm open to sponsorships that align with my content and provide " +
        "value to my audience. Send me a DM with your proposal!",
      category: "collaboration",
      order: 15,
    },
  ];

  try {
    logger.info("🌱 Starting FAQ seeding...");

    const batch = db.batch();

    for (const faq of faqs) {
      const docRef = db.collection("faqs").doc(faq.id);
      batch.set(docRef, {
        question: faq.question,
        answer: faq.answer,
        category: faq.category,
        order: faq.order,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    logger.info(`✅ Successfully seeded ${faqs.length} FAQs`);

    res.status(200).json({
      success: true,
      message: `Successfully seeded ${faqs.length} FAQs`,
      faqs: faqs.map((f) => ({id: f.id, question: f.question})),
    });
  } catch (error) {
    logger.error("❌ Error seeding FAQs:", error);
    res.status(500).json({
      error: "Failed to seed FAQs",
      details: error instanceof Error ? error.message : String(error),
    });
  }
});

/**
 * Seed creator profile to Firestore
 * GET https://us-central1-buzzbox-ios.cloudfunctions.net/seedCreatorProfile
 */
export const seedCreatorProfile = onRequest({region: "us-central1"}, async (req, res) => {
  const db = admin.firestore();

  const profile = {
    personality: "Friendly tech content creator who loves helping people learn " +
      "iOS development. Casual but professional, authentic and enthusiastic " +
      "about building great apps.",

    tone: "warm, encouraging, uses emojis occasionally, conversational but knowledgeable",

    examples: [
      "Hey! Thanks so much for reaching out! 🙌",
      "That's awesome! I'd love to hear more about your project.",
      "Appreciate the kind words, it really means a lot!",
      "Great question! Here's how I approach that...",
      "Let me know if you need anything else, always happy to help!",
      "Totally get what you're saying - ran into that same issue myself!",
      "Love the enthusiasm! Keep building and learning! 🚀",
      "For sure! Check out this resource, it helped me a ton:",
    ],

    avoid: [
      "Overly formal language",
      "Corporate speak",
      "Robotic responses",
      "Generic templates",
      "Passive voice",
      "Jargon without explanation",
    ],

    signature: "- Andrew",
  };

  try {
    logger.info("🌱 Starting creator profile seeding...");

    await db.collection("creator_profiles").doc("andrew").set({
      ...profile,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      version: 1,
    });

    logger.info("✅ Successfully seeded creator profile");

    res.status(200).json({
      success: true,
      message: "Successfully seeded creator profile",
      profile: {
        personality: profile.personality.substring(0, 70) + "...",
        examplesCount: profile.examples.length,
        avoidCount: profile.avoid.length,
      },
    });
  } catch (error) {
    logger.error("❌ Error seeding creator profile:", error);
    res.status(500).json({
      error: "Failed to seed creator profile",
      details: error instanceof Error ? error.message : String(error),
    });
  }
});
