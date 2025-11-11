import Foundation

/// Centralized location for all Claude AI prompts used in the app
enum ClaudePrompts {

    // MARK: - Note Extraction Prompt

    static func noteExtractionPrompt(rawInput: String, sections: [NoteSection]) -> String {
        let sectionsDesc = sections.map { section in
            "- **\(section.title)**: \(section.aiExtractionPrompt)"
        }.joined(separator: "\n")

        return """
        You are helping a Steel Challenge shooter create structured notes about their shooting session.

        The shooter has provided this input:
        "\(rawInput)"

        Extract information into these sections:
        \(sectionsDesc)

        Return ONLY a JSON object with this EXACT structure:
        {
          "summary": "Brief one-sentence summary (e.g., 'Good practice, no issues', 'Challenging session with equipment problems', 'Great match performance')",
          "sections": {
            "match_performance": "extracted content or empty string if not mentioned",
            "equipment": "extracted content or empty string if not mentioned",
            "conditions": "extracted content or empty string if not mentioned",
            "mental": "extracted content or empty string if not mentioned",
            "physical": "extracted content or empty string if not mentioned",
            "social": "extracted content or empty string if not mentioned",
            "improvement_areas": "extracted content or empty string if not mentioned",
            "other": "extracted content or empty string if not mentioned"
          },
          "quality": {
            "match_performance": 1-5 or null if not mentioned,
            "equipment": 1-5 or null if not mentioned,
            "conditions": 1-5 or null if not mentioned,
            "mental": 1-5 or null if not mentioned,
            "physical": 1-5 or null if not mentioned,
            "social": 1-5 or null if not mentioned,
            "improvement_areas": 1-5 or null if not mentioned,
            "other": 1-5 or null if not mentioned
          },
          "missingInfoPrompts": [
            "Specific question about what info to add (e.g., 'How was the weather?')",
            "Another specific question (e.g., 'Any equipment issues?')"
          ],
          "hasMinimalDetail": true or false
        }

        IMPORTANT - Summary Guidelines:
        - Create a brief, high-level one-sentence summary of the session
        - Focus on overall tone and key takeaway (e.g., "Good practice, no issues", "Challenging match with equipment problems", "Great performance, made GM")
        - Keep it concise and actionable
        - Should capture the essence of the session at a glance

        IMPORTANT - Missing Info Prompts:
        - If key required sections are empty, add 2-4 specific questions to prompt the user
        - Make questions natural and conversational (e.g., "How was the weather?" not "Please provide weather")
        - Prioritize the most important missing information
        - If note is complete, return empty array []

        IMPORTANT - Minimal Detail Assessment:
        - Set hasMinimalDetail to FALSE if the input is too vague or lacks substance
        - Examples of too little detail: "good", "fine", "ok", single word responses
        - Set to TRUE if there's enough specific information to work with
        - Even if sections are missing, if what's provided has good detail, set to TRUE

        Guidelines for sections:
        - ALWAYS write in FIRST PERSON, past tense - these are the shooter's personal notes
        - Write like you're summarizing your own day (e.g., "I felt tired", "My equipment worked well", "The weather was hot")
        - NEVER use third person (NEVER say "The shooter felt..." or "The shooter's equipment...")
        - Be concise but complete
        - Only include information actually mentioned
        - Use empty string "" if section not mentioned
        - Preserve specific details (temps, times, names)

        Guidelines for quality ratings (1-5 scale):
        - 5 = Excellent/Optimal (e.g., "perfect weather", "felt great", "equipment worked flawlessly", "made GM", "achieved goals", "no issues", "no problems", "worked well")
        - 4 = Good/Above average (e.g., "weather was nice", "felt good")
        - 3 = Average/Neutral (e.g., "weather was okay", "felt normal", "minor issues")
        - 2 = Below average (e.g., "cold/hot weather", "felt tired", "some problems")
        - 1 = Poor/Problems (e.g., "terrible weather", "felt awful", "major malfunctions")
        - null = Not mentioned or not applicable
        - Base rating on the TONE and CONTENT of what was said
        - If nothing mentioned, use null (not 3)
        - IMPORTANT: "No issues", "no problems", "worked well", "everything worked" = 5/5 (EXCELLENT), not 4/5

        CRITICAL SCORING RULES:

        0. POSITIVE LANGUAGE SCORING (APPLIES TO ALL CATEGORIES):
           - EXCELLENT (5/5): "great", "excellent", "amazing", "fantastic", "awesome", "perfect", "outstanding", "loved", "best ever", "no issues", "no problems", "worked well", "everything worked", "flawless"
           - GOOD (4/5): "good", "nice", "solid", "fine", "decent", "went well"
           - NEUTRAL (3/5): "okay", "alright", "normal", "average", "so-so"
           - When someone says "the match was great" or "performance was great" → ALWAYS 5/5
           - When someone says "no issues" or "no problems" or "worked well" → ALWAYS 5/5
           - When someone says "it was good" → 4/5
           - Default to the most positive interpretation of positive language

        1. SOCIAL / Practicing Alone:
           - Practicing alone is NEUTRAL (3/5), NOT negative
           - Only rate low if explicitly negative (e.g., "squad was unfriendly", "bad atmosphere")
           - Fun/enjoyable/great social experience (e.g., "squad was fun", "had a blast", "enjoyed shooting with") = EXCELLENT (5/5)
           - Neutral mention of shooting with others (e.g., "shot with friends") = GOOD (4/5)

        2. THINGS TO WORK ON:
           - Constructive goals (e.g., "need to focus on transitions", "work on my draw") = NEUTRAL/GOOD (3-4/5)
           - Only rate low (1-2/5) if EXPLICITLY negative (e.g., "I was terrible", "shooting poorly", "struggled badly")
           - Achievements mentioned here = 5/5
           - Default to 3-4/5 for practice goals - they show awareness and growth mindset

        3. MENTAL STATE:
           - This is about FEELINGS only: confident/nervous, focused/distracted, tired/energized, stressed/calm
           - DO NOT put technique goals here (e.g., "focus on transitions" belongs in Things to Work On)
           - Rate based on emotional/mental feelings, not skills to practice
        """
    }

    // MARK: - Note Update Prompt

    static func noteUpdatePrompt(currentContent: NoteContent, additionalInput: String, targetCategory: String? = nil) -> String {
        let currentSectionsJSON = currentContent.sections.map { key, value in
            "    \"\(key)\": \"\(value)\""
        }.joined(separator: ",\n")

        let currentQualityJSON = currentContent.quality.map { key, value in
            "    \"\(key)\": \(value)"
        }.joined(separator: ",\n")

        var categoryInstruction = ""
        if let category = targetCategory {
            categoryInstruction = "\n\nIMPORTANT: The shooter wants to add this specifically to the '\(category)' category. Focus the update on that category."
        }

        return """
        You are helping update structured shooting session notes.

        Current note content:
        {
          "sections": {
        \(currentSectionsJSON)
          },
          "quality": {
        \(currentQualityJSON)
          }
        }

        The shooter has added this information:
        "\(additionalInput)"\(categoryInstruction)

        Merge this new information into the existing note. Update relevant sections and quality ratings.
        - ALWAYS write in FIRST PERSON (e.g., "My equipment worked well", "I felt tired") - NEVER third person
        - If new info improves a category, increase quality rating
        - If new info mentions issues, decrease quality rating
        - Preserve existing content that's not contradicted
        - "No issues", "no problems", "worked well" = 5/5 rating

        IMPORTANT: If the new information doesn't belong to the target category, place it in the appropriate category instead.
        Redistribute content as needed to ensure each piece of information is in the most logical section.

        Return ONLY a JSON object with this structure:
        {
          "summary": "Brief one-sentence summary of the overall session",
          "sections": {
            "match_performance": "...",
            "equipment": "...",
            "conditions": "...",
            "mental": "...",
            "physical": "...",
            "social": "...",
            "improvement_areas": "...",
            "other": "..."
          },
          "quality": {
            "match_performance": 1-5 or null,
            "equipment": 1-5 or null,
            "conditions": 1-5 or null,
            "mental": 1-5 or null,
            "physical": 1-5 or null,
            "social": 1-5 or null,
            "improvement_areas": 1-5 or null,
            "other": 1-5 or null
          }
        }
        """
    }
}
