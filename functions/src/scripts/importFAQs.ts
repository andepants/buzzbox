/**
 * Import FAQs Script
 *
 * Imports FAQ data from faqs-preseed.json into Firestore.
 * Run with: npm run import-faqs
 */

import * as admin from "firebase-admin";
import * as fs from "fs";
import * as path from "path";

// Initialize Firebase Admin
admin.initializeApp({
  projectId: "buzzbox-ios",
});

const db = admin.firestore();

interface FAQ {
  id: string;
  question: string;
  answer: string;
  category: string;
  keywords: string[];
}

interface FAQData {
  faqs: FAQ[];
}

async function importFAQs() {
  try {
    console.log("🚀 Starting FAQ import...\n");

    // Read the FAQ data file
    const dataPath = path.join(__dirname, "../../../docs/data/faqs-preseed.json");
    console.log(`📁 Reading FAQs from: ${dataPath}`);

    const rawData = fs.readFileSync(dataPath, "utf-8");
    const data: FAQData = JSON.parse(rawData);

    console.log(`📊 Found ${data.faqs.length} FAQs to import\n`);

    // Import each FAQ
    const batch = db.batch();

    for (const faq of data.faqs) {
      const docRef = db.collection("faqs").doc(faq.id);

      // Create document with all fields except 'id' (that's the document ID)
      batch.set(docRef, {
        question: faq.question,
        answer: faq.answer,
        category: faq.category,
        keywords: faq.keywords,
        embedding: null, // Will be populated by Cloud Function later
      });

      console.log(`✅ Queued: ${faq.id} - "${faq.question}"`);
    }

    // Commit the batch
    console.log("\n💾 Writing to Firestore...");
    await batch.commit();

    console.log("\n🎉 Success! All FAQs imported to Firestore");
    console.log("\n📍 Collection: faqs");
    console.log(`📍 Documents: ${data.faqs.length}`);
    console.log("\n💡 Next: Run Story 6.3 to generate embeddings for these FAQs\n");

    process.exit(0);
  } catch (error) {
    console.error("\n❌ Error importing FAQs:", error);
    process.exit(1);
  }
}

// Run the import
importFAQs();
