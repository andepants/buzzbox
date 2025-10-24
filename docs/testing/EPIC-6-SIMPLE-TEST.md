# Epic 6: AI Features - Simple Testing Checklist

**Quick Test Guide:** Use 2 devices/simulators - one as Creator (andrewsheim@gmail.com), one as Fan

---

## Setup
- [ ] Creator logged in on Device 1
- [ ] Fan logged in on Device 2
- [ ] Both can send/receive messages
- [ ] Start a DM conversation between Creator and Fan

---

## Feature 1: Conversation-Level Visual Indicators (NEW - Story 6.11)

**Setup:** Create a business conversation first

**Device 2 (Fan)** → Send to Creator:
- [ ] **Test 1:** Send "Hi! I'm interested in a $5000 sponsorship for your tech channel"
- [ ] **Test 2:** Send 2-3 more professional messages about partnership details

**Device 1 (Creator):**
- [ ] **Test 3:** Go back to inbox/conversation list
- [ ] **Test 4:** Verify conversation shows:
  - Green "Business" badge with briefcase icon
  - Business score badge (e.g., "7/10") in green/yellow/red
  - Subtle border color around conversation card
- [ ] **Test 5:** Conversation card is easily identifiable as business opportunity

---

## Feature 2: Smart Reply Floating Buttons (UPDATED - Story 6.10)

**Setup:** Have existing conversation with 5+ messages

**Device 1 (Creator):**
- [ ] **Test 1:** Open a DM conversation → Verify sparkles FAB appears above input (center-bottom)
- [ ] **Test 2:** Tap sparkles FAB → Verify 3 buttons expand (Short, Funny, Pro)
- [ ] **Test 3:** Tap "Short" (blue button) → Verify loading spinner appears
- [ ] **Test 4:** Wait ~2 seconds → Verify short reply populates message input
- [ ] **Test 5:** Verify FABs collapse after reply generated
- [ ] **Test 6:** Edit reply if needed → Send message
- [ ] **Test 7:** Repeat with "Funny" (orange) and "Pro" (purple) buttons
- [ ] **Test 8:** Verify each reply type has distinct tone (short/playful/professional)

---

## Feature 3: FAQ Auto-Responder (6 points)

**Device 2 (Fan)** → Send to Creator:
- [ ] **Test 1:** Send "What time do you stream?" → Auto-response appears in 1-2 seconds
- [ ] **Test 2:** Check auto-response has "AI Response" sparkles badge

---

## Feature 4: Message-Level Sentiment Analysis (6 points)

**Device 2 (Fan)** → Send to Creator:
- [ ] **Test 1:** Send "Thank you so much! You're awesome!" → Check Device 1 shows green indicator (positive)
- [ ] **Test 2:** Send "I'm frustrated with this!" → Check Device 1 shows red indicator (negative)
- [ ] **Test 3:** Verify sentiment indicators appear on individual messages inside conversation

---

## Feature 5: Category Detection on Conversation Cards

**Setup:** Create different conversation types

**Device 2 (Fan)** → Create multiple test conversations:

**Test 1 - Regular Fan:**
- [ ] Send "I love your videos!" and other appreciative messages
- [ ] Device 1: Check conversation list shows blue "Fan" badge

**Test 2 - Super Fan:**
- [ ] Send 10+ enthusiastic messages over time
- [ ] Device 1: Check conversation list shows purple "Super Fan" badge with star

**Test 3 - Urgent:**
- [ ] Send "URGENT: Live stream is down right now!"
- [ ] Device 1: Check conversation shows orange "Urgent" badge with exclamation mark
- [ ] Verify orange border around conversation card

**Test 4 - Spam:**
- [ ] Send generic spam-like message
- [ ] Device 1: Check conversation is grayed out (50% opacity)
- [ ] Verify gray "Spam" badge shows

---

## Feature 6 (Advanced): Context-Aware Smart Replies (10 points)

**Setup:** Have 10+ message back-and-forth conversation

**Device 1 (Creator):**
- [ ] **Test 1:** Expand FAB buttons → Generate replies using all 3 types
- [ ] **Test 2:** Verify replies reference conversation context (not generic)
- [ ] **Test 3:** Check all 3 options (Short/Funny/Professional) are contextually relevant
- [ ] **Test 4:** Verify replies sound like Andrew's voice and tone

---

## Quick Validation Checklist

**Story 6.10 (Floating FAB):**
- [ ] Sparkles FAB appears centered above message input
- [ ] FAB expands to 3 distinct buttons (Short, Funny, Pro)
- [ ] Each button generates appropriate reply type
- [ ] Replies populate input immediately for editing
- [ ] FABs collapse after generation
- [ ] Smooth animations (spring effect)
- [ ] Loading states work (spinner on tapped button)

**Story 6.11 (Conversation-Level Analysis):**
- [ ] Conversation cards show sentiment borders (green/red/orange/gray)
- [ ] Category badges appear (Fan, Super Fan, Business, Spam, Urgent)
- [ ] Business score badge appears only for business conversations (0-10 scale)
- [ ] Score colors match ranges (7-10 green, 4-6 yellow, 0-3 red)
- [ ] Spam conversations grayed out (50% opacity)
- [ ] Urgent conversations have orange border and badge
- [ ] Analysis triggers when creator opens inbox
- [ ] Re-analysis happens when new messages arrive

**Performance & UX:**
- [ ] Response times: Smart Replies <3s
- [ ] No lag when opening inbox with multiple conversations
- [ ] All AI badges visible on creator's device
- [ ] Conversation list easy to scan and triage

---

## If Something Doesn't Work

**Check Firebase Console:**
- Functions: https://console.firebase.google.com/project/buzzbox-ios/functions
- Logs: `firebase functions:log --limit 10`
- RTDB: Check if AI metadata exists on messages

**Common Issues:**
- No badges? → Check Cloud Functions deployed: `firebase functions:list`
- No auto-response? → Check FAQ toggle in Settings → AI Settings
- Slow responses? → Check OpenAI API limits: https://platform.openai.com/usage

---

**Total Test Time:** ~15 minutes

**Score if All Pass:** 40/40 points (40% of total project grade) ✅
