package com.rupee.dto.response;

import com.rupee.enums.TicketEnums.Priority;
import com.rupee.enums.TicketEnums.Status;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDateTime;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class TicketResponse {
    private Long id;

    // ✅ ADDED: Expose the custom ticket ID to the frontend
    private String ticketNumber;


    private Long userId;
    private Long consultantId;
    private String category;
    private String description;
    private String attachmentUrl;
    private Priority priority;
    private Status status;

    // --- SLA COMPLIANCE ---
    private LocalDateTime slaRespondBy;
    private LocalDateTime slaResolveBy;
    private boolean isSlaBreached;

    // ✅ NEW: Added to expose response time data to the frontend UI
    private LocalDateTime firstRespondedAt;

    // --- ESCALATION TRACKING ---
    private boolean isEscalated;
    private LocalDateTime escalatedAt;
    private String escalationReason;

    // --- FEEDBACK ---
    private Integer feedbackRating;
    private String feedbackText;

    // --- TIMESTAMPS ---
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    // ✅ SECURED: internalNotes field has been completely removed to prevent data leaks.
    // Agents should use the dedicated /{id}/notes endpoint to fetch these securely.
}