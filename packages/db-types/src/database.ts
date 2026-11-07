export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.18"
  }
  public: {
    Tables: {
      application_documents: {
        Row: {
          application_id: string
          created_at: string
          id: string
          kind: string
          storage_path: string
        }
        Insert: {
          application_id: string
          created_at?: string
          id?: string
          kind: string
          storage_path: string
        }
        Update: {
          application_id?: string
          created_at?: string
          id?: string
          kind?: string
          storage_path?: string
        }
        Relationships: [
          {
            foreignKeyName: "application_documents_application_id_fkey"
            columns: ["application_id"]
            isOneToOne: false
            referencedRelation: "provider_applications"
            referencedColumns: ["id"]
          },
        ]
      }
      availability_exceptions: {
        Row: {
          during: unknown
          id: string
          kind: Database["public"]["Enums"]["exception_kind"]
          note: string | null
          resource_id: string
        }
        Insert: {
          during: unknown
          id?: string
          kind: Database["public"]["Enums"]["exception_kind"]
          note?: string | null
          resource_id: string
        }
        Update: {
          during?: unknown
          id?: string
          kind?: Database["public"]["Enums"]["exception_kind"]
          note?: string | null
          resource_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "availability_exceptions_resource_id_fkey"
            columns: ["resource_id"]
            isOneToOne: false
            referencedRelation: "provider_resources"
            referencedColumns: ["id"]
          },
        ]
      }
      availability_rules: {
        Row: {
          end_time: string
          id: string
          resource_id: string
          start_time: string
          valid_from: string | null
          valid_to: string | null
          weekday: number
        }
        Insert: {
          end_time: string
          id?: string
          resource_id: string
          start_time: string
          valid_from?: string | null
          valid_to?: string | null
          weekday: number
        }
        Update: {
          end_time?: string
          id?: string
          resource_id?: string
          start_time?: string
          valid_from?: string | null
          valid_to?: string | null
          weekday?: number
        }
        Relationships: [
          {
            foreignKeyName: "availability_rules_resource_id_fkey"
            columns: ["resource_id"]
            isOneToOne: false
            referencedRelation: "provider_resources"
            referencedColumns: ["id"]
          },
        ]
      }
      booking_checklist: {
        Row: {
          booking_id: string
          checked_at: string
          checked_by: string
          item_code: string
          note: string | null
          ok: boolean
          value: string | null
        }
        Insert: {
          booking_id: string
          checked_at?: string
          checked_by: string
          item_code: string
          note?: string | null
          ok: boolean
          value?: string | null
        }
        Update: {
          booking_id?: string
          checked_at?: string
          checked_by?: string
          item_code?: string
          note?: string | null
          ok?: boolean
          value?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "booking_checklist_booking_id_fkey"
            columns: ["booking_id"]
            isOneToOne: false
            referencedRelation: "bookings"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "booking_checklist_item_code_fkey"
            columns: ["item_code"]
            isOneToOne: false
            referencedRelation: "checklist_items"
            referencedColumns: ["code"]
          },
        ]
      }
      booking_commissions: {
        Row: {
          booking_id: string
          commission_cents: number
          created_at: string
        }
        Insert: {
          booking_id: string
          commission_cents: number
          created_at?: string
        }
        Update: {
          booking_id?: string
          commission_cents?: number
          created_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "booking_commissions_booking_id_fkey"
            columns: ["booking_id"]
            isOneToOne: true
            referencedRelation: "bookings"
            referencedColumns: ["id"]
          },
        ]
      }
      booking_photos: {
        Row: {
          booking_id: string
          created_at: string
          id: string
          item_code: string | null
          kind: Database["public"]["Enums"]["photo_kind"]
          storage_path: string
          uploaded_by: string
        }
        Insert: {
          booking_id: string
          created_at?: string
          id?: string
          item_code?: string | null
          kind: Database["public"]["Enums"]["photo_kind"]
          storage_path: string
          uploaded_by: string
        }
        Update: {
          booking_id?: string
          created_at?: string
          id?: string
          item_code?: string | null
          kind?: Database["public"]["Enums"]["photo_kind"]
          storage_path?: string
          uploaded_by?: string
        }
        Relationships: [
          {
            foreignKeyName: "booking_photos_booking_id_fkey"
            columns: ["booking_id"]
            isOneToOne: false
            referencedRelation: "bookings"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "booking_photos_item_code_fkey"
            columns: ["item_code"]
            isOneToOne: false
            referencedRelation: "checklist_items"
            referencedColumns: ["code"]
          },
        ]
      }
      bookings: {
        Row: {
          address: string | null
          address_location: unknown
          auto_complete_at: string | null
          cancel_reason: string | null
          cancelled_at: string | null
          completed_at: string | null
          completion_method:
            | Database["public"]["Enums"]["completion_method"]
            | null
          confirmed_at: string | null
          contact: Json | null
          created_at: string
          customer_id: string
          customer_note: string | null
          customer_total_cents: number | null
          during: unknown
          hold_expires_at: string | null
          hold_extended: boolean
          id: string
          location_type: Database["public"]["Enums"]["location_type"]
          payment_due_at: string | null
          payment_requested_at: string | null
          price_cents: number
          provider_id: string
          provider_service_id: string
          reminder_sent_at: string | null
          resource_id: string
          retorque_reminder_at: string | null
          retorque_reminder_sent_at: string | null
          service_fee_cents: number
          service_id: string
          started_at: string | null
          status: Database["public"]["Enums"]["booking_status"]
          total_cents: number | null
          travel_fee_cents: number
          updated_at: string
          vehicle_id: string | null
          work_done_at: string | null
        }
        Insert: {
          address?: string | null
          address_location?: unknown
          auto_complete_at?: string | null
          cancel_reason?: string | null
          cancelled_at?: string | null
          completed_at?: string | null
          completion_method?:
            | Database["public"]["Enums"]["completion_method"]
            | null
          confirmed_at?: string | null
          contact?: Json | null
          created_at?: string
          customer_id: string
          customer_note?: string | null
          customer_total_cents?: number | null
          during: unknown
          hold_expires_at?: string | null
          hold_extended?: boolean
          id?: string
          location_type: Database["public"]["Enums"]["location_type"]
          payment_due_at?: string | null
          payment_requested_at?: string | null
          price_cents: number
          provider_id: string
          provider_service_id: string
          reminder_sent_at?: string | null
          resource_id: string
          retorque_reminder_at?: string | null
          retorque_reminder_sent_at?: string | null
          service_fee_cents?: number
          service_id: string
          started_at?: string | null
          status?: Database["public"]["Enums"]["booking_status"]
          total_cents?: number | null
          travel_fee_cents?: number
          updated_at?: string
          vehicle_id?: string | null
          work_done_at?: string | null
        }
        Update: {
          address?: string | null
          address_location?: unknown
          auto_complete_at?: string | null
          cancel_reason?: string | null
          cancelled_at?: string | null
          completed_at?: string | null
          completion_method?:
            | Database["public"]["Enums"]["completion_method"]
            | null
          confirmed_at?: string | null
          contact?: Json | null
          created_at?: string
          customer_id?: string
          customer_note?: string | null
          customer_total_cents?: number | null
          during?: unknown
          hold_expires_at?: string | null
          hold_extended?: boolean
          id?: string
          location_type?: Database["public"]["Enums"]["location_type"]
          payment_due_at?: string | null
          payment_requested_at?: string | null
          price_cents?: number
          provider_id?: string
          provider_service_id?: string
          reminder_sent_at?: string | null
          resource_id?: string
          retorque_reminder_at?: string | null
          retorque_reminder_sent_at?: string | null
          service_fee_cents?: number
          service_id?: string
          started_at?: string | null
          status?: Database["public"]["Enums"]["booking_status"]
          total_cents?: number | null
          travel_fee_cents?: number
          updated_at?: string
          vehicle_id?: string | null
          work_done_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "bookings_provider_id_fkey"
            columns: ["provider_id"]
            isOneToOne: false
            referencedRelation: "providers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bookings_provider_service_id_fkey"
            columns: ["provider_service_id"]
            isOneToOne: false
            referencedRelation: "provider_services"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bookings_resource_id_fkey"
            columns: ["resource_id"]
            isOneToOne: false
            referencedRelation: "provider_resources"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bookings_service_id_fkey"
            columns: ["service_id"]
            isOneToOne: false
            referencedRelation: "services"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bookings_vehicle_id_fkey"
            columns: ["vehicle_id"]
            isOneToOne: false
            referencedRelation: "vehicles"
            referencedColumns: ["id"]
          },
        ]
      }
      checklist_items: {
        Row: {
          active: boolean
          code: string
          help: Json | null
          label: Json
          requires_photo: boolean
          sort_order: number
        }
        Insert: {
          active?: boolean
          code: string
          help?: Json | null
          label: Json
          requires_photo?: boolean
          sort_order?: number
        }
        Update: {
          active?: boolean
          code?: string
          help?: Json | null
          label?: Json
          requires_photo?: boolean
          sort_order?: number
        }
        Relationships: []
      }
      cities: {
        Row: {
          active: boolean
          center: unknown
          code: string
          created_at: string
          id: string
          name: Json
          timezone: string
          updated_at: string
        }
        Insert: {
          active?: boolean
          center: unknown
          code: string
          created_at?: string
          id?: string
          name: Json
          timezone?: string
          updated_at?: string
        }
        Update: {
          active?: boolean
          center?: unknown
          code?: string
          created_at?: string
          id?: string
          name?: Json
          timezone?: string
          updated_at?: string
        }
        Relationships: []
      }
      city_slugs: {
        Row: {
          city_id: string
          locale: Database["public"]["Enums"]["locale"]
          slug: string
        }
        Insert: {
          city_id: string
          locale: Database["public"]["Enums"]["locale"]
          slug: string
        }
        Update: {
          city_id?: string
          locale?: Database["public"]["Enums"]["locale"]
          slug?: string
        }
        Relationships: [
          {
            foreignKeyName: "city_slugs_city_id_fkey"
            columns: ["city_id"]
            isOneToOne: false
            referencedRelation: "cities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "city_slugs_city_id_fkey"
            columns: ["city_id"]
            isOneToOne: false
            referencedRelation: "city_stats"
            referencedColumns: ["city_id"]
          },
        ]
      }
      dispute_messages: {
        Row: {
          author_id: string
          body: string
          created_at: string
          dispute_id: string
          id: string
        }
        Insert: {
          author_id: string
          body: string
          created_at?: string
          dispute_id: string
          id?: string
        }
        Update: {
          author_id?: string
          body?: string
          created_at?: string
          dispute_id?: string
          id?: string
        }
        Relationships: [
          {
            foreignKeyName: "dispute_messages_dispute_id_fkey"
            columns: ["dispute_id"]
            isOneToOne: false
            referencedRelation: "disputes"
            referencedColumns: ["id"]
          },
        ]
      }
      disputes: {
        Row: {
          booking_id: string
          booking_status_at_open: Database["public"]["Enums"]["booking_status"]
          description: string
          id: string
          opened_at: string
          opened_by: string
          opened_by_role: string
          reason: Database["public"]["Enums"]["dispute_reason"]
          refund_cents: number | null
          resolution_note: string | null
          resolved_at: string | null
          resolved_by: string | null
          status: Database["public"]["Enums"]["dispute_status"]
          updated_at: string
        }
        Insert: {
          booking_id: string
          booking_status_at_open: Database["public"]["Enums"]["booking_status"]
          description: string
          id?: string
          opened_at?: string
          opened_by: string
          opened_by_role: string
          reason: Database["public"]["Enums"]["dispute_reason"]
          refund_cents?: number | null
          resolution_note?: string | null
          resolved_at?: string | null
          resolved_by?: string | null
          status?: Database["public"]["Enums"]["dispute_status"]
          updated_at?: string
        }
        Update: {
          booking_id?: string
          booking_status_at_open?: Database["public"]["Enums"]["booking_status"]
          description?: string
          id?: string
          opened_at?: string
          opened_by?: string
          opened_by_role?: string
          reason?: Database["public"]["Enums"]["dispute_reason"]
          refund_cents?: number | null
          resolution_note?: string | null
          resolved_at?: string | null
          resolved_by?: string | null
          status?: Database["public"]["Enums"]["dispute_status"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "disputes_booking_id_fkey"
            columns: ["booking_id"]
            isOneToOne: false
            referencedRelation: "bookings"
            referencedColumns: ["id"]
          },
        ]
      }
      district_slugs: {
        Row: {
          city_id: string
          district_id: string
          locale: Database["public"]["Enums"]["locale"]
          slug: string
        }
        Insert: {
          city_id: string
          district_id: string
          locale: Database["public"]["Enums"]["locale"]
          slug: string
        }
        Update: {
          city_id?: string
          district_id?: string
          locale?: Database["public"]["Enums"]["locale"]
          slug?: string
        }
        Relationships: [
          {
            foreignKeyName: "district_slugs_city_id_fkey"
            columns: ["city_id"]
            isOneToOne: false
            referencedRelation: "cities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "district_slugs_city_id_fkey"
            columns: ["city_id"]
            isOneToOne: false
            referencedRelation: "city_stats"
            referencedColumns: ["city_id"]
          },
          {
            foreignKeyName: "district_slugs_district_id_fkey"
            columns: ["district_id"]
            isOneToOne: false
            referencedRelation: "districts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "district_slugs_district_id_fkey"
            columns: ["district_id"]
            isOneToOne: false
            referencedRelation: "published_districts"
            referencedColumns: ["district_id"]
          },
        ]
      }
      districts: {
        Row: {
          center: unknown
          city_id: string
          code: string
          created_at: string
          id: string
          name: Json
        }
        Insert: {
          center?: unknown
          city_id: string
          code: string
          created_at?: string
          id?: string
          name: Json
        }
        Update: {
          center?: unknown
          city_id?: string
          code?: string
          created_at?: string
          id?: string
          name?: Json
        }
        Relationships: [
          {
            foreignKeyName: "districts_city_id_fkey"
            columns: ["city_id"]
            isOneToOne: false
            referencedRelation: "cities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "districts_city_id_fkey"
            columns: ["city_id"]
            isOneToOne: false
            referencedRelation: "city_stats"
            referencedColumns: ["city_id"]
          },
        ]
      }
      notification_preferences: {
        Row: {
          email: boolean
          marketing: boolean
          push: boolean
          sms: boolean
          updated_at: string
          user_id: string
        }
        Insert: {
          email?: boolean
          marketing?: boolean
          push?: boolean
          sms?: boolean
          updated_at?: string
          user_id: string
        }
        Update: {
          email?: boolean
          marketing?: boolean
          push?: boolean
          sms?: boolean
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      notifications: {
        Row: {
          booking_id: string | null
          channel: Database["public"]["Enums"]["notification_channel"]
          created_at: string
          error: string | null
          id: string
          outbox_event_id: number | null
          payload: Json
          read_at: string | null
          sent_at: string | null
          status: Database["public"]["Enums"]["notification_status"]
          template: string
          user_id: string
        }
        Insert: {
          booking_id?: string | null
          channel: Database["public"]["Enums"]["notification_channel"]
          created_at?: string
          error?: string | null
          id?: string
          outbox_event_id?: number | null
          payload?: Json
          read_at?: string | null
          sent_at?: string | null
          status?: Database["public"]["Enums"]["notification_status"]
          template: string
          user_id: string
        }
        Update: {
          booking_id?: string | null
          channel?: Database["public"]["Enums"]["notification_channel"]
          created_at?: string
          error?: string | null
          id?: string
          outbox_event_id?: number | null
          payload?: Json
          read_at?: string | null
          sent_at?: string | null
          status?: Database["public"]["Enums"]["notification_status"]
          template?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "notifications_booking_id_fkey"
            columns: ["booking_id"]
            isOneToOne: false
            referencedRelation: "bookings"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notifications_outbox_event_id_fkey"
            columns: ["outbox_event_id"]
            isOneToOne: false
            referencedRelation: "outbox_events"
            referencedColumns: ["id"]
          },
        ]
      }
      outbox_events: {
        Row: {
          aggregate_id: string
          attempts: number
          available_at: string
          created_at: string
          failed_at: string | null
          id: number
          last_error: string | null
          locked_until: string | null
          payload: Json
          processed_at: string | null
          type: string
        }
        Insert: {
          aggregate_id: string
          attempts?: number
          available_at?: string
          created_at?: string
          failed_at?: string | null
          id?: never
          last_error?: string | null
          locked_until?: string | null
          payload?: Json
          processed_at?: string | null
          type: string
        }
        Update: {
          aggregate_id?: string
          attempts?: number
          available_at?: string
          created_at?: string
          failed_at?: string | null
          id?: never
          last_error?: string | null
          locked_until?: string | null
          payload?: Json
          processed_at?: string | null
          type?: string
        }
        Relationships: []
      }
      payment_events: {
        Row: {
          error: string | null
          external_event_id: string
          id: number
          payload: Json
          payment_provider: Database["public"]["Enums"]["payment_provider"]
          processed_at: string | null
          received_at: string
          type: string
        }
        Insert: {
          error?: string | null
          external_event_id: string
          id?: never
          payload: Json
          payment_provider?: Database["public"]["Enums"]["payment_provider"]
          processed_at?: string | null
          received_at?: string
          type: string
        }
        Update: {
          error?: string | null
          external_event_id?: string
          id?: never
          payload?: Json
          payment_provider?: Database["public"]["Enums"]["payment_provider"]
          processed_at?: string | null
          received_at?: string
          type?: string
        }
        Relationships: []
      }
      payments: {
        Row: {
          amount_cents: number
          application_fee_cents: number
          authorization_expires_at: string | null
          authorized_at: string | null
          booking_id: string
          canceled_at: string | null
          captured_at: string | null
          created_at: string
          currency: string
          expiry_handled_at: string | null
          external_id: string
          failure_reason: string | null
          id: string
          method: string | null
          payment_provider: Database["public"]["Enums"]["payment_provider"]
          status: Database["public"]["Enums"]["payment_status"]
          updated_at: string
        }
        Insert: {
          amount_cents: number
          application_fee_cents?: number
          authorization_expires_at?: string | null
          authorized_at?: string | null
          booking_id: string
          canceled_at?: string | null
          captured_at?: string | null
          created_at?: string
          currency?: string
          expiry_handled_at?: string | null
          external_id: string
          failure_reason?: string | null
          id?: string
          method?: string | null
          payment_provider?: Database["public"]["Enums"]["payment_provider"]
          status?: Database["public"]["Enums"]["payment_status"]
          updated_at?: string
        }
        Update: {
          amount_cents?: number
          application_fee_cents?: number
          authorization_expires_at?: string | null
          authorized_at?: string | null
          booking_id?: string
          canceled_at?: string | null
          captured_at?: string | null
          created_at?: string
          currency?: string
          expiry_handled_at?: string | null
          external_id?: string
          failure_reason?: string | null
          id?: string
          method?: string | null
          payment_provider?: Database["public"]["Enums"]["payment_provider"]
          status?: Database["public"]["Enums"]["payment_status"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "payments_booking_id_fkey"
            columns: ["booking_id"]
            isOneToOne: false
            referencedRelation: "bookings"
            referencedColumns: ["id"]
          },
        ]
      }
      payouts: {
        Row: {
          amount_cents: number
          arrival_date: string | null
          created_at: string
          currency: string
          external_id: string
          id: string
          provider_id: string
          status: string
          updated_at: string
        }
        Insert: {
          amount_cents: number
          arrival_date?: string | null
          created_at?: string
          currency?: string
          external_id: string
          id?: string
          provider_id: string
          status: string
          updated_at?: string
        }
        Update: {
          amount_cents?: number
          arrival_date?: string | null
          created_at?: string
          currency?: string
          external_id?: string
          id?: string
          provider_id?: string
          status?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "payouts_provider_id_fkey"
            columns: ["provider_id"]
            isOneToOne: false
            referencedRelation: "providers"
            referencedColumns: ["id"]
          },
        ]
      }
      platform_settings: {
        Row: {
          authorization_lead_days: number
          auto_complete_hours: number
          cancel_unpaid_hours: number
          customer_service_fee_cents: number
          default_commission_bps: number
          dispute_window_days: number
          id: boolean
          immediate_authorization_days: number
          payment_grace_minutes: number
          payments_enabled: boolean
          retorque_reminder_days: number
          review_window_days: number
          updated_at: string
        }
        Insert: {
          authorization_lead_days?: number
          auto_complete_hours?: number
          cancel_unpaid_hours?: number
          customer_service_fee_cents?: number
          default_commission_bps?: number
          dispute_window_days?: number
          id?: boolean
          immediate_authorization_days?: number
          payment_grace_minutes?: number
          payments_enabled?: boolean
          retorque_reminder_days?: number
          review_window_days?: number
          updated_at?: string
        }
        Update: {
          authorization_lead_days?: number
          auto_complete_hours?: number
          cancel_unpaid_hours?: number
          customer_service_fee_cents?: number
          default_commission_bps?: number
          dispute_window_days?: number
          id?: boolean
          immediate_authorization_days?: number
          payment_grace_minutes?: number
          payments_enabled?: boolean
          retorque_reminder_days?: number
          review_window_days?: number
          updated_at?: string
        }
        Relationships: []
      }
      postal_codes: {
        Row: {
          center: unknown
          city_id: string
          code: string
          district_id: string | null
        }
        Insert: {
          center: unknown
          city_id: string
          code: string
          district_id?: string | null
        }
        Update: {
          center?: unknown
          city_id?: string
          code?: string
          district_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "postal_codes_city_id_fkey"
            columns: ["city_id"]
            isOneToOne: false
            referencedRelation: "cities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "postal_codes_city_id_fkey"
            columns: ["city_id"]
            isOneToOne: false
            referencedRelation: "city_stats"
            referencedColumns: ["city_id"]
          },
          {
            foreignKeyName: "postal_codes_district_id_fkey"
            columns: ["district_id"]
            isOneToOne: false
            referencedRelation: "districts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "postal_codes_district_id_fkey"
            columns: ["district_id"]
            isOneToOne: false
            referencedRelation: "published_districts"
            referencedColumns: ["district_id"]
          },
        ]
      }
      profiles: {
        Row: {
          created_at: string
          full_name: string | null
          id: string
          locale: Database["public"]["Enums"]["locale"]
          phone: string | null
          updated_at: string
        }
        Insert: {
          created_at?: string
          full_name?: string | null
          id: string
          locale?: Database["public"]["Enums"]["locale"]
          phone?: string | null
          updated_at?: string
        }
        Update: {
          created_at?: string
          full_name?: string | null
          id?: string
          locale?: Database["public"]["Enums"]["locale"]
          phone?: string | null
          updated_at?: string
        }
        Relationships: []
      }
      provider_applications: {
        Row: {
          business_id: string | null
          city_id: string
          contact_email: string | null
          contact_phone: string | null
          course_completed_at: string | null
          course_version: string | null
          created_at: string
          description: string | null
          display_name: string
          district_id: string | null
          id: string
          identity_provider: string | null
          identity_subject: string | null
          identity_verified_at: string | null
          invoicing_reference: string | null
          invoicing_service: Database["public"]["Enums"]["invoicing_service"]
          is_adult: boolean | null
          kind: Database["public"]["Enums"]["provider_kind"]
          location_types: Database["public"]["Enums"]["location_type"][]
          provider_id: string | null
          rejection_reason: string | null
          reviewed_at: string | null
          reviewed_by: string | null
          status: Database["public"]["Enums"]["application_status"]
          submitted_at: string | null
          terms_accepted_at: string | null
          terms_version: string | null
          tools_description: string | null
          updated_at: string
          user_id: string
        }
        Insert: {
          business_id?: string | null
          city_id: string
          contact_email?: string | null
          contact_phone?: string | null
          course_completed_at?: string | null
          course_version?: string | null
          created_at?: string
          description?: string | null
          display_name: string
          district_id?: string | null
          id?: string
          identity_provider?: string | null
          identity_subject?: string | null
          identity_verified_at?: string | null
          invoicing_reference?: string | null
          invoicing_service?: Database["public"]["Enums"]["invoicing_service"]
          is_adult?: boolean | null
          kind: Database["public"]["Enums"]["provider_kind"]
          location_types?: Database["public"]["Enums"]["location_type"][]
          provider_id?: string | null
          rejection_reason?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: Database["public"]["Enums"]["application_status"]
          submitted_at?: string | null
          terms_accepted_at?: string | null
          terms_version?: string | null
          tools_description?: string | null
          updated_at?: string
          user_id?: string
        }
        Update: {
          business_id?: string | null
          city_id?: string
          contact_email?: string | null
          contact_phone?: string | null
          course_completed_at?: string | null
          course_version?: string | null
          created_at?: string
          description?: string | null
          display_name?: string
          district_id?: string | null
          id?: string
          identity_provider?: string | null
          identity_subject?: string | null
          identity_verified_at?: string | null
          invoicing_reference?: string | null
          invoicing_service?: Database["public"]["Enums"]["invoicing_service"]
          is_adult?: boolean | null
          kind?: Database["public"]["Enums"]["provider_kind"]
          location_types?: Database["public"]["Enums"]["location_type"][]
          provider_id?: string | null
          rejection_reason?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: Database["public"]["Enums"]["application_status"]
          submitted_at?: string | null
          terms_accepted_at?: string | null
          terms_version?: string | null
          tools_description?: string | null
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "provider_applications_city_id_fkey"
            columns: ["city_id"]
            isOneToOne: false
            referencedRelation: "cities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "provider_applications_city_id_fkey"
            columns: ["city_id"]
            isOneToOne: false
            referencedRelation: "city_stats"
            referencedColumns: ["city_id"]
          },
          {
            foreignKeyName: "provider_applications_district_id_fkey"
            columns: ["district_id"]
            isOneToOne: false
            referencedRelation: "districts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "provider_applications_district_id_fkey"
            columns: ["district_id"]
            isOneToOne: false
            referencedRelation: "published_districts"
            referencedColumns: ["district_id"]
          },
          {
            foreignKeyName: "provider_applications_provider_id_fkey"
            columns: ["provider_id"]
            isOneToOne: false
            referencedRelation: "providers"
            referencedColumns: ["id"]
          },
        ]
      }
      provider_commission_overrides: {
        Row: {
          commission_bps: number
          created_at: string
          note: string | null
          provider_id: string
          updated_at: string
          valid_until: string | null
        }
        Insert: {
          commission_bps: number
          created_at?: string
          note?: string | null
          provider_id: string
          updated_at?: string
          valid_until?: string | null
        }
        Update: {
          commission_bps?: number
          created_at?: string
          note?: string | null
          provider_id?: string
          updated_at?: string
          valid_until?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "provider_commission_overrides_provider_id_fkey"
            columns: ["provider_id"]
            isOneToOne: true
            referencedRelation: "providers"
            referencedColumns: ["id"]
          },
        ]
      }
      provider_members: {
        Row: {
          created_at: string
          provider_id: string
          role: Database["public"]["Enums"]["member_role"]
          user_id: string
        }
        Insert: {
          created_at?: string
          provider_id: string
          role?: Database["public"]["Enums"]["member_role"]
          user_id: string
        }
        Update: {
          created_at?: string
          provider_id?: string
          role?: Database["public"]["Enums"]["member_role"]
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "provider_members_provider_id_fkey"
            columns: ["provider_id"]
            isOneToOne: false
            referencedRelation: "providers"
            referencedColumns: ["id"]
          },
        ]
      }
      provider_payout_accounts: {
        Row: {
          charges_enabled: boolean
          created_at: string
          details_submitted: boolean
          external_account_id: string
          payment_provider: Database["public"]["Enums"]["payment_provider"]
          payouts_enabled: boolean
          provider_id: string
          requirements: Json | null
          updated_at: string
        }
        Insert: {
          charges_enabled?: boolean
          created_at?: string
          details_submitted?: boolean
          external_account_id: string
          payment_provider?: Database["public"]["Enums"]["payment_provider"]
          payouts_enabled?: boolean
          provider_id: string
          requirements?: Json | null
          updated_at?: string
        }
        Update: {
          charges_enabled?: boolean
          created_at?: string
          details_submitted?: boolean
          external_account_id?: string
          payment_provider?: Database["public"]["Enums"]["payment_provider"]
          payouts_enabled?: boolean
          provider_id?: string
          requirements?: Json | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "provider_payout_accounts_provider_id_fkey"
            columns: ["provider_id"]
            isOneToOne: true
            referencedRelation: "providers"
            referencedColumns: ["id"]
          },
        ]
      }
      provider_private: {
        Row: {
          business_id: string | null
          contact_email: string | null
          contact_phone: string | null
          exact_location: unknown
          iban: string | null
          postal_code: string | null
          provider_id: string
          street_address: string | null
          updated_at: string
        }
        Insert: {
          business_id?: string | null
          contact_email?: string | null
          contact_phone?: string | null
          exact_location?: unknown
          iban?: string | null
          postal_code?: string | null
          provider_id: string
          street_address?: string | null
          updated_at?: string
        }
        Update: {
          business_id?: string | null
          contact_email?: string | null
          contact_phone?: string | null
          exact_location?: unknown
          iban?: string | null
          postal_code?: string | null
          provider_id?: string
          street_address?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "provider_private_provider_id_fkey"
            columns: ["provider_id"]
            isOneToOne: true
            referencedRelation: "providers"
            referencedColumns: ["id"]
          },
        ]
      }
      provider_resources: {
        Row: {
          active: boolean
          created_at: string
          id: string
          location_type: Database["public"]["Enums"]["location_type"]
          name: string
          provider_id: string
        }
        Insert: {
          active?: boolean
          created_at?: string
          id?: string
          location_type: Database["public"]["Enums"]["location_type"]
          name: string
          provider_id: string
        }
        Update: {
          active?: boolean
          created_at?: string
          id?: string
          location_type?: Database["public"]["Enums"]["location_type"]
          name?: string
          provider_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "provider_resources_provider_id_fkey"
            columns: ["provider_id"]
            isOneToOne: false
            referencedRelation: "providers"
            referencedColumns: ["id"]
          },
        ]
      }
      provider_services: {
        Row: {
          active: boolean
          created_at: string
          duration_min: number
          id: string
          location_type: Database["public"]["Enums"]["location_type"]
          price_cents: number
          provider_id: string
          service_id: string
          travel_fee_cents: number
          updated_at: string
        }
        Insert: {
          active?: boolean
          created_at?: string
          duration_min: number
          id?: string
          location_type: Database["public"]["Enums"]["location_type"]
          price_cents: number
          provider_id: string
          service_id: string
          travel_fee_cents?: number
          updated_at?: string
        }
        Update: {
          active?: boolean
          created_at?: string
          duration_min?: number
          id?: string
          location_type?: Database["public"]["Enums"]["location_type"]
          price_cents?: number
          provider_id?: string
          service_id?: string
          travel_fee_cents?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "provider_services_provider_id_fkey"
            columns: ["provider_id"]
            isOneToOne: false
            referencedRelation: "providers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "provider_services_service_id_fkey"
            columns: ["service_id"]
            isOneToOne: false
            referencedRelation: "services"
            referencedColumns: ["id"]
          },
        ]
      }
      provider_tax_info: {
        Row: {
          birth_date: string | null
          city: string | null
          country: string
          legal_name: string
          postal_code: string | null
          provider_id: string
          street_address: string | null
          tax_id: string | null
          updated_at: string
          vat_number: string | null
        }
        Insert: {
          birth_date?: string | null
          city?: string | null
          country?: string
          legal_name: string
          postal_code?: string | null
          provider_id: string
          street_address?: string | null
          tax_id?: string | null
          updated_at?: string
          vat_number?: string | null
        }
        Update: {
          birth_date?: string | null
          city?: string | null
          country?: string
          legal_name?: string
          postal_code?: string | null
          provider_id?: string
          street_address?: string | null
          tax_id?: string | null
          updated_at?: string
          vat_number?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "provider_tax_info_provider_id_fkey"
            columns: ["provider_id"]
            isOneToOne: true
            referencedRelation: "providers"
            referencedColumns: ["id"]
          },
        ]
      }
      providers: {
        Row: {
          city_id: string
          created_at: string
          description: Json | null
          display_name: string
          district_id: string | null
          id: string
          kind: Database["public"]["Enums"]["provider_kind"]
          location: unknown
          max_days_ahead: number
          min_notice_minutes: number
          published_at: string | null
          rating_avg: number | null
          rating_count: number
          service_radius_km: number | null
          slug: string
          status: Database["public"]["Enums"]["provider_status"]
          updated_at: string
        }
        Insert: {
          city_id: string
          created_at?: string
          description?: Json | null
          display_name: string
          district_id?: string | null
          id?: string
          kind: Database["public"]["Enums"]["provider_kind"]
          location: unknown
          max_days_ahead?: number
          min_notice_minutes?: number
          published_at?: string | null
          rating_avg?: number | null
          rating_count?: number
          service_radius_km?: number | null
          slug: string
          status?: Database["public"]["Enums"]["provider_status"]
          updated_at?: string
        }
        Update: {
          city_id?: string
          created_at?: string
          description?: Json | null
          display_name?: string
          district_id?: string | null
          id?: string
          kind?: Database["public"]["Enums"]["provider_kind"]
          location?: unknown
          max_days_ahead?: number
          min_notice_minutes?: number
          published_at?: string | null
          rating_avg?: number | null
          rating_count?: number
          service_radius_km?: number | null
          slug?: string
          status?: Database["public"]["Enums"]["provider_status"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "providers_city_id_fkey"
            columns: ["city_id"]
            isOneToOne: false
            referencedRelation: "cities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "providers_city_id_fkey"
            columns: ["city_id"]
            isOneToOne: false
            referencedRelation: "city_stats"
            referencedColumns: ["city_id"]
          },
          {
            foreignKeyName: "providers_district_id_fkey"
            columns: ["district_id"]
            isOneToOne: false
            referencedRelation: "districts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "providers_district_id_fkey"
            columns: ["district_id"]
            isOneToOne: false
            referencedRelation: "published_districts"
            referencedColumns: ["district_id"]
          },
        ]
      }
      refunds: {
        Row: {
          amount_cents: number
          created_at: string
          dispute_id: string | null
          external_id: string
          id: string
          payment_id: string
          reason: string | null
          status: string
          updated_at: string
        }
        Insert: {
          amount_cents: number
          created_at?: string
          dispute_id?: string | null
          external_id: string
          id?: string
          payment_id: string
          reason?: string | null
          status?: string
          updated_at?: string
        }
        Update: {
          amount_cents?: number
          created_at?: string
          dispute_id?: string | null
          external_id?: string
          id?: string
          payment_id?: string
          reason?: string | null
          status?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "refunds_dispute_fk"
            columns: ["dispute_id"]
            isOneToOne: false
            referencedRelation: "disputes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "refunds_payment_id_fkey"
            columns: ["payment_id"]
            isOneToOne: false
            referencedRelation: "payment_settlements"
            referencedColumns: ["payment_id"]
          },
          {
            foreignKeyName: "refunds_payment_id_fkey"
            columns: ["payment_id"]
            isOneToOne: false
            referencedRelation: "payments"
            referencedColumns: ["id"]
          },
        ]
      }
      reviews: {
        Row: {
          author_id: string
          body: string | null
          booking_id: string
          created_at: string
          id: string
          locale: Database["public"]["Enums"]["locale"]
          provider_id: string
          published: boolean
          rating: number
        }
        Insert: {
          author_id: string
          body?: string | null
          booking_id: string
          created_at?: string
          id?: string
          locale?: Database["public"]["Enums"]["locale"]
          provider_id: string
          published?: boolean
          rating: number
        }
        Update: {
          author_id?: string
          body?: string | null
          booking_id?: string
          created_at?: string
          id?: string
          locale?: Database["public"]["Enums"]["locale"]
          provider_id?: string
          published?: boolean
          rating?: number
        }
        Relationships: [
          {
            foreignKeyName: "reviews_booking_id_fkey"
            columns: ["booking_id"]
            isOneToOne: true
            referencedRelation: "bookings"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reviews_provider_id_fkey"
            columns: ["provider_id"]
            isOneToOne: false
            referencedRelation: "providers"
            referencedColumns: ["id"]
          },
        ]
      }
      services: {
        Row: {
          active: boolean
          code: string
          default_duration_min: number
          description: Json | null
          id: string
          name: Json
          sort_order: number
        }
        Insert: {
          active?: boolean
          code: string
          default_duration_min: number
          description?: Json | null
          id?: string
          name: Json
          sort_order?: number
        }
        Update: {
          active?: boolean
          code?: string
          default_duration_min?: number
          description?: Json | null
          id?: string
          name?: Json
          sort_order?: number
        }
        Relationships: []
      }
      user_devices: {
        Row: {
          created_at: string
          id: string
          last_seen_at: string
          platform: Database["public"]["Enums"]["device_platform"]
          push_token: string
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          last_seen_at?: string
          platform: Database["public"]["Enums"]["device_platform"]
          push_token: string
          user_id: string
        }
        Update: {
          created_at?: string
          id?: string
          last_seen_at?: string
          platform?: Database["public"]["Enums"]["device_platform"]
          push_token?: string
          user_id?: string
        }
        Relationships: []
      }
      vehicles: {
        Row: {
          created_at: string
          id: string
          nickname: string | null
          owner_id: string
          plate: string | null
          tire_size: string | null
          updated_at: string
        }
        Insert: {
          created_at?: string
          id?: string
          nickname?: string | null
          owner_id: string
          plate?: string | null
          tire_size?: string | null
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: string
          nickname?: string | null
          owner_id?: string
          plate?: string | null
          tire_size?: string | null
          updated_at?: string
        }
        Relationships: []
      }
    }
    Views: {
      city_stats: {
        Row: {
          avg_rating: number | null
          city_id: string | null
          location_type: Database["public"]["Enums"]["location_type"] | null
          min_price_cents: number | null
          provider_count: number | null
          service_code: string | null
        }
        Relationships: []
      }
      payment_settlements: {
        Row: {
          booking_id: string | null
          captured_at: string | null
          commission_cents: number | null
          gross_cents: number | null
          net_cents: number | null
          payment_id: string | null
          provider_id: string | null
          refunded_cents: number | null
        }
        Relationships: [
          {
            foreignKeyName: "bookings_provider_id_fkey"
            columns: ["provider_id"]
            isOneToOne: false
            referencedRelation: "providers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payments_booking_id_fkey"
            columns: ["booking_id"]
            isOneToOne: false
            referencedRelation: "bookings"
            referencedColumns: ["id"]
          },
        ]
      }
      provider_earnings: {
        Row: {
          commission_cents: number | null
          gross_cents: number | null
          job_count: number | null
          month: string | null
          net_cents: number | null
          provider_id: string | null
          refunded_cents: number | null
        }
        Relationships: [
          {
            foreignKeyName: "bookings_provider_id_fkey"
            columns: ["provider_id"]
            isOneToOne: false
            referencedRelation: "providers"
            referencedColumns: ["id"]
          },
        ]
      }
      published_districts: {
        Row: {
          city_id: string | null
          code: string | null
          district_id: string | null
          name: Json | null
          provider_count: number | null
        }
        Relationships: [
          {
            foreignKeyName: "districts_city_id_fkey"
            columns: ["city_id"]
            isOneToOne: false
            referencedRelation: "cities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "districts_city_id_fkey"
            columns: ["city_id"]
            isOneToOne: false
            referencedRelation: "city_stats"
            referencedColumns: ["city_id"]
          },
        ]
      }
    }
    Functions: {
      accept_provider_terms: {
        Args: { p_application_id: string; p_terms_version: string }
        Returns: {
          business_id: string | null
          city_id: string
          contact_email: string | null
          contact_phone: string | null
          course_completed_at: string | null
          course_version: string | null
          created_at: string
          description: string | null
          display_name: string
          district_id: string | null
          id: string
          identity_provider: string | null
          identity_subject: string | null
          identity_verified_at: string | null
          invoicing_reference: string | null
          invoicing_service: Database["public"]["Enums"]["invoicing_service"]
          is_adult: boolean | null
          kind: Database["public"]["Enums"]["provider_kind"]
          location_types: Database["public"]["Enums"]["location_type"][]
          provider_id: string | null
          rejection_reason: string | null
          reviewed_at: string | null
          reviewed_by: string | null
          status: Database["public"]["Enums"]["application_status"]
          submitted_at: string | null
          terms_accepted_at: string | null
          terms_version: string | null
          tools_description: string | null
          updated_at: string
          user_id: string
        }
        SetofOptions: {
          from: "*"
          to: "provider_applications"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      add_dispute_message: {
        Args: { p_body: string; p_dispute_id: string }
        Returns: {
          author_id: string
          body: string
          created_at: string
          dispute_id: string
          id: string
        }
        SetofOptions: {
          from: "*"
          to: "dispute_messages"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      admin_dac7_report: {
        Args: { p_year: number }
        Returns: {
          birth_date: string
          city: string
          country: string
          fees_cents: number
          iban: string
          legal_name: string
          postal_code: string
          provider_id: string
          q1_activities: number
          q1_consideration_cents: number
          q2_activities: number
          q2_consideration_cents: number
          q3_activities: number
          q3_consideration_cents: number
          q4_activities: number
          q4_consideration_cents: number
          street_address: string
          tax_id: string
          vat_number: string
        }[]
      }
      admin_resolve_dispute: {
        Args: {
          p_dispute_id: string
          p_note?: string
          p_outcome: Database["public"]["Enums"]["dispute_status"]
          p_refund_cents?: number
        }
        Returns: {
          booking_id: string
          booking_status_at_open: Database["public"]["Enums"]["booking_status"]
          description: string
          id: string
          opened_at: string
          opened_by: string
          opened_by_role: string
          reason: Database["public"]["Enums"]["dispute_reason"]
          refund_cents: number | null
          resolution_note: string | null
          resolved_at: string | null
          resolved_by: string | null
          status: Database["public"]["Enums"]["dispute_status"]
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "disputes"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      admin_review_application: {
        Args: {
          p_application_id: string
          p_approve: boolean
          p_reason?: string
        }
        Returns: {
          business_id: string | null
          city_id: string
          contact_email: string | null
          contact_phone: string | null
          course_completed_at: string | null
          course_version: string | null
          created_at: string
          description: string | null
          display_name: string
          district_id: string | null
          id: string
          identity_provider: string | null
          identity_subject: string | null
          identity_verified_at: string | null
          invoicing_reference: string | null
          invoicing_service: Database["public"]["Enums"]["invoicing_service"]
          is_adult: boolean | null
          kind: Database["public"]["Enums"]["provider_kind"]
          location_types: Database["public"]["Enums"]["location_type"][]
          provider_id: string | null
          rejection_reason: string | null
          reviewed_at: string | null
          reviewed_by: string | null
          status: Database["public"]["Enums"]["application_status"]
          submitted_at: string | null
          terms_accepted_at: string | null
          terms_version: string | null
          tools_description: string | null
          updated_at: string
          user_id: string
        }
        SetofOptions: {
          from: "*"
          to: "provider_applications"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      admin_set_provider_status: {
        Args: {
          p_provider_id: string
          p_status: Database["public"]["Enums"]["provider_status"]
        }
        Returns: {
          city_id: string
          created_at: string
          description: Json | null
          display_name: string
          district_id: string | null
          id: string
          kind: Database["public"]["Enums"]["provider_kind"]
          location: unknown
          max_days_ahead: number
          min_notice_minutes: number
          published_at: string | null
          rating_avg: number | null
          rating_count: number
          service_radius_km: number | null
          slug: string
          status: Database["public"]["Enums"]["provider_status"]
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "providers"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      cancel_booking: {
        Args: { p_booking_id: string; p_reason?: string }
        Returns: {
          address: string | null
          address_location: unknown
          auto_complete_at: string | null
          cancel_reason: string | null
          cancelled_at: string | null
          completed_at: string | null
          completion_method:
            | Database["public"]["Enums"]["completion_method"]
            | null
          confirmed_at: string | null
          contact: Json | null
          created_at: string
          customer_id: string
          customer_note: string | null
          customer_total_cents: number | null
          during: unknown
          hold_expires_at: string | null
          hold_extended: boolean
          id: string
          location_type: Database["public"]["Enums"]["location_type"]
          payment_due_at: string | null
          payment_requested_at: string | null
          price_cents: number
          provider_id: string
          provider_service_id: string
          reminder_sent_at: string | null
          resource_id: string
          retorque_reminder_at: string | null
          retorque_reminder_sent_at: string | null
          service_fee_cents: number
          service_id: string
          started_at: string | null
          status: Database["public"]["Enums"]["booking_status"]
          total_cents: number | null
          travel_fee_cents: number
          updated_at: string
          vehicle_id: string | null
          work_done_at: string | null
        }
        SetofOptions: {
          from: "*"
          to: "bookings"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      complete_job: {
        Args: { p_booking_id: string }
        Returns: {
          address: string | null
          address_location: unknown
          auto_complete_at: string | null
          cancel_reason: string | null
          cancelled_at: string | null
          completed_at: string | null
          completion_method:
            | Database["public"]["Enums"]["completion_method"]
            | null
          confirmed_at: string | null
          contact: Json | null
          created_at: string
          customer_id: string
          customer_note: string | null
          customer_total_cents: number | null
          during: unknown
          hold_expires_at: string | null
          hold_extended: boolean
          id: string
          location_type: Database["public"]["Enums"]["location_type"]
          payment_due_at: string | null
          payment_requested_at: string | null
          price_cents: number
          provider_id: string
          provider_service_id: string
          reminder_sent_at: string | null
          resource_id: string
          retorque_reminder_at: string | null
          retorque_reminder_sent_at: string | null
          service_fee_cents: number
          service_id: string
          started_at: string | null
          status: Database["public"]["Enums"]["booking_status"]
          total_cents: number | null
          travel_fee_cents: number
          updated_at: string
          vehicle_id: string | null
          work_done_at: string | null
        }
        SetofOptions: {
          from: "*"
          to: "bookings"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      confirm_booking: {
        Args: {
          p_address?: string
          p_booking_id: string
          p_contact: Json
          p_note?: string
          p_vehicle_id?: string
        }
        Returns: {
          address: string | null
          address_location: unknown
          auto_complete_at: string | null
          cancel_reason: string | null
          cancelled_at: string | null
          completed_at: string | null
          completion_method:
            | Database["public"]["Enums"]["completion_method"]
            | null
          confirmed_at: string | null
          contact: Json | null
          created_at: string
          customer_id: string
          customer_note: string | null
          customer_total_cents: number | null
          during: unknown
          hold_expires_at: string | null
          hold_extended: boolean
          id: string
          location_type: Database["public"]["Enums"]["location_type"]
          payment_due_at: string | null
          payment_requested_at: string | null
          price_cents: number
          provider_id: string
          provider_service_id: string
          reminder_sent_at: string | null
          resource_id: string
          retorque_reminder_at: string | null
          retorque_reminder_sent_at: string | null
          service_fee_cents: number
          service_id: string
          started_at: string | null
          status: Database["public"]["Enums"]["booking_status"]
          total_cents: number | null
          travel_fee_cents: number
          updated_at: string
          vehicle_id: string | null
          work_done_at: string | null
        }
        SetofOptions: {
          from: "*"
          to: "bookings"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      confirm_job_completion: {
        Args: { p_booking_id: string }
        Returns: {
          address: string | null
          address_location: unknown
          auto_complete_at: string | null
          cancel_reason: string | null
          cancelled_at: string | null
          completed_at: string | null
          completion_method:
            | Database["public"]["Enums"]["completion_method"]
            | null
          confirmed_at: string | null
          contact: Json | null
          created_at: string
          customer_id: string
          customer_note: string | null
          customer_total_cents: number | null
          during: unknown
          hold_expires_at: string | null
          hold_extended: boolean
          id: string
          location_type: Database["public"]["Enums"]["location_type"]
          payment_due_at: string | null
          payment_requested_at: string | null
          price_cents: number
          provider_id: string
          provider_service_id: string
          reminder_sent_at: string | null
          resource_id: string
          retorque_reminder_at: string | null
          retorque_reminder_sent_at: string | null
          service_fee_cents: number
          service_id: string
          started_at: string | null
          status: Database["public"]["Enums"]["booking_status"]
          total_cents: number | null
          travel_fee_cents: number
          updated_at: string
          vehicle_id: string | null
          work_done_at: string | null
        }
        SetofOptions: {
          from: "*"
          to: "bookings"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      extend_hold: {
        Args: { p_booking_id: string }
        Returns: {
          address: string | null
          address_location: unknown
          auto_complete_at: string | null
          cancel_reason: string | null
          cancelled_at: string | null
          completed_at: string | null
          completion_method:
            | Database["public"]["Enums"]["completion_method"]
            | null
          confirmed_at: string | null
          contact: Json | null
          created_at: string
          customer_id: string
          customer_note: string | null
          customer_total_cents: number | null
          during: unknown
          hold_expires_at: string | null
          hold_extended: boolean
          id: string
          location_type: Database["public"]["Enums"]["location_type"]
          payment_due_at: string | null
          payment_requested_at: string | null
          price_cents: number
          provider_id: string
          provider_service_id: string
          reminder_sent_at: string | null
          resource_id: string
          retorque_reminder_at: string | null
          retorque_reminder_sent_at: string | null
          service_fee_cents: number
          service_id: string
          started_at: string | null
          status: Database["public"]["Enums"]["booking_status"]
          total_cents: number | null
          travel_fee_cents: number
          updated_at: string
          vehicle_id: string | null
          work_done_at: string | null
        }
        SetofOptions: {
          from: "*"
          to: "bookings"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      get_available_slots: {
        Args: {
          p_from: string
          p_location_type: Database["public"]["Enums"]["location_type"]
          p_provider_id: string
          p_service_code: string
          p_to: string
        }
        Returns: {
          ends_at: string
          free_resources: number
          starts_at: string
        }[]
      }
      hold_slot: {
        Args: {
          p_location_type: Database["public"]["Enums"]["location_type"]
          p_provider_id: string
          p_service_code: string
          p_starts_at: string
        }
        Returns: {
          address: string | null
          address_location: unknown
          auto_complete_at: string | null
          cancel_reason: string | null
          cancelled_at: string | null
          completed_at: string | null
          completion_method:
            | Database["public"]["Enums"]["completion_method"]
            | null
          confirmed_at: string | null
          contact: Json | null
          created_at: string
          customer_id: string
          customer_note: string | null
          customer_total_cents: number | null
          during: unknown
          hold_expires_at: string | null
          hold_extended: boolean
          id: string
          location_type: Database["public"]["Enums"]["location_type"]
          payment_due_at: string | null
          payment_requested_at: string | null
          price_cents: number
          provider_id: string
          provider_service_id: string
          reminder_sent_at: string | null
          resource_id: string
          retorque_reminder_at: string | null
          retorque_reminder_sent_at: string | null
          service_fee_cents: number
          service_id: string
          started_at: string | null
          status: Database["public"]["Enums"]["booking_status"]
          total_cents: number | null
          travel_fee_cents: number
          updated_at: string
          vehicle_id: string | null
          work_done_at: string | null
        }
        SetofOptions: {
          from: "*"
          to: "bookings"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      is_i18n_text: { Args: { value: Json }; Returns: boolean }
      open_dispute: {
        Args: {
          p_booking_id: string
          p_description: string
          p_reason: Database["public"]["Enums"]["dispute_reason"]
        }
        Returns: {
          booking_id: string
          booking_status_at_open: Database["public"]["Enums"]["booking_status"]
          description: string
          id: string
          opened_at: string
          opened_by: string
          opened_by_role: string
          reason: Database["public"]["Enums"]["dispute_reason"]
          refund_cents: number | null
          resolution_note: string | null
          resolved_at: string | null
          resolved_by: string | null
          status: Database["public"]["Enums"]["dispute_status"]
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "disputes"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      register_booking_photo: {
        Args: {
          p_booking_id: string
          p_item_code?: string
          p_kind: Database["public"]["Enums"]["photo_kind"]
          p_storage_path: string
        }
        Returns: {
          booking_id: string
          created_at: string
          id: string
          item_code: string | null
          kind: Database["public"]["Enums"]["photo_kind"]
          storage_path: string
          uploaded_by: string
        }
        SetofOptions: {
          from: "*"
          to: "booking_photos"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      register_device: {
        Args: {
          p_platform: Database["public"]["Enums"]["device_platform"]
          p_push_token: string
        }
        Returns: {
          created_at: string
          id: string
          last_seen_at: string
          platform: Database["public"]["Enums"]["device_platform"]
          push_token: string
          user_id: string
        }
        SetofOptions: {
          from: "*"
          to: "user_devices"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      save_checklist_item: {
        Args: {
          p_booking_id: string
          p_item_code: string
          p_note?: string
          p_ok: boolean
          p_value?: string
        }
        Returns: {
          booking_id: string
          checked_at: string
          checked_by: string
          item_code: string
          note: string | null
          ok: boolean
          value: string | null
        }
        SetofOptions: {
          from: "*"
          to: "booking_checklist"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      search_providers: {
        Args: {
          p_city_slug: string
          p_date?: string
          p_district_slug?: string
          p_lat?: number
          p_limit?: number
          p_lng?: number
          p_locale?: Database["public"]["Enums"]["locale"]
          p_location_type?: Database["public"]["Enums"]["location_type"]
          p_offset?: number
          p_provider_kind?: Database["public"]["Enums"]["provider_kind"]
          p_service_code?: string
          p_time_from?: string
          p_time_to?: string
        }
        Returns: {
          display_name: string
          distance_m: number
          district_name: string
          duration_min: number
          first_free_at: string
          free_slots: number
          kind: Database["public"]["Enums"]["provider_kind"]
          location_type: Database["public"]["Enums"]["location_type"]
          price_cents: number
          provider_count: number
          provider_id: string
          rating_avg: number
          rating_count: number
          slug: string
          total_count: number
          travel_fee_cents: number
        }[]
      }
      start_job: {
        Args: { p_booking_id: string }
        Returns: {
          address: string | null
          address_location: unknown
          auto_complete_at: string | null
          cancel_reason: string | null
          cancelled_at: string | null
          completed_at: string | null
          completion_method:
            | Database["public"]["Enums"]["completion_method"]
            | null
          confirmed_at: string | null
          contact: Json | null
          created_at: string
          customer_id: string
          customer_note: string | null
          customer_total_cents: number | null
          during: unknown
          hold_expires_at: string | null
          hold_extended: boolean
          id: string
          location_type: Database["public"]["Enums"]["location_type"]
          payment_due_at: string | null
          payment_requested_at: string | null
          price_cents: number
          provider_id: string
          provider_service_id: string
          reminder_sent_at: string | null
          resource_id: string
          retorque_reminder_at: string | null
          retorque_reminder_sent_at: string | null
          service_fee_cents: number
          service_id: string
          started_at: string | null
          status: Database["public"]["Enums"]["booking_status"]
          total_cents: number | null
          travel_fee_cents: number
          updated_at: string
          vehicle_id: string | null
          work_done_at: string | null
        }
        SetofOptions: {
          from: "*"
          to: "bookings"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      submit_provider_application: {
        Args: { p_application_id: string }
        Returns: {
          business_id: string | null
          city_id: string
          contact_email: string | null
          contact_phone: string | null
          course_completed_at: string | null
          course_version: string | null
          created_at: string
          description: string | null
          display_name: string
          district_id: string | null
          id: string
          identity_provider: string | null
          identity_subject: string | null
          identity_verified_at: string | null
          invoicing_reference: string | null
          invoicing_service: Database["public"]["Enums"]["invoicing_service"]
          is_adult: boolean | null
          kind: Database["public"]["Enums"]["provider_kind"]
          location_types: Database["public"]["Enums"]["location_type"][]
          provider_id: string | null
          rejection_reason: string | null
          reviewed_at: string | null
          reviewed_by: string | null
          status: Database["public"]["Enums"]["application_status"]
          submitted_at: string | null
          terms_accepted_at: string | null
          terms_version: string | null
          tools_description: string | null
          updated_at: string
          user_id: string
        }
        SetofOptions: {
          from: "*"
          to: "provider_applications"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      submit_review: {
        Args: {
          p_body?: string
          p_booking_id: string
          p_locale?: Database["public"]["Enums"]["locale"]
          p_rating: number
        }
        Returns: {
          author_id: string
          body: string | null
          booking_id: string
          created_at: string
          id: string
          locale: Database["public"]["Enums"]["locale"]
          provider_id: string
          published: boolean
          rating: number
        }
        SetofOptions: {
          from: "*"
          to: "reviews"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      t: {
        Args: { lang: Database["public"]["Enums"]["locale"]; value: Json }
        Returns: string
      }
      withdraw_dispute: {
        Args: { p_dispute_id: string }
        Returns: {
          booking_id: string
          booking_status_at_open: Database["public"]["Enums"]["booking_status"]
          description: string
          id: string
          opened_at: string
          opened_by: string
          opened_by_role: string
          reason: Database["public"]["Enums"]["dispute_reason"]
          refund_cents: number | null
          resolution_note: string | null
          resolved_at: string | null
          resolved_by: string | null
          status: Database["public"]["Enums"]["dispute_status"]
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "disputes"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      worker_claim_outbox_events: {
        Args: { p_limit?: number; p_lock?: string; p_types?: string[] }
        Returns: {
          aggregate_id: string
          attempts: number
          available_at: string
          created_at: string
          failed_at: string | null
          id: number
          last_error: string | null
          locked_until: string | null
          payload: Json
          processed_at: string | null
          type: string
        }[]
        SetofOptions: {
          from: "*"
          to: "outbox_events"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      worker_complete_outbox_event: {
        Args: { p_error?: string; p_id: number }
        Returns: undefined
      }
    }
    Enums: {
      application_status:
        | "draft"
        | "submitted"
        | "in_review"
        | "approved"
        | "rejected"
        | "withdrawn"
      booking_status:
        | "held"
        | "confirmed"
        | "in_progress"
        | "work_done"
        | "completed"
        | "disputed"
        | "cancelled"
        | "expired"
      completion_method: "customer" | "auto" | "admin"
      device_platform: "ios" | "android" | "web"
      dispute_reason:
        | "quality"
        | "damage"
        | "provider_no_show"
        | "customer_no_show"
        | "price"
        | "other"
      dispute_status:
        | "open"
        | "in_review"
        | "resolved_no_action"
        | "resolved_partial_refund"
        | "resolved_refund"
        | "withdrawn"
      exception_kind: "closed" | "open"
      invoicing_service: "none" | "ukko" | "eezy" | "other"
      locale: "fi" | "sv" | "en"
      location_type: "workshop" | "mobile"
      member_role: "owner" | "staff"
      notification_channel: "push" | "email" | "sms"
      notification_status: "pending" | "sent" | "failed" | "skipped"
      payment_provider: "stripe" | "fake"
      payment_status:
        | "pending"
        | "requires_action"
        | "authorized"
        | "captured"
        | "canceled"
        | "failed"
        | "partially_refunded"
        | "refunded"
      photo_kind: "before" | "after" | "checklist" | "damage" | "dispute"
      provider_kind: "company" | "individual"
      provider_status: "pending" | "active" | "suspended"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      application_status: [
        "draft",
        "submitted",
        "in_review",
        "approved",
        "rejected",
        "withdrawn",
      ],
      booking_status: [
        "held",
        "confirmed",
        "in_progress",
        "work_done",
        "completed",
        "disputed",
        "cancelled",
        "expired",
      ],
      completion_method: ["customer", "auto", "admin"],
      device_platform: ["ios", "android", "web"],
      dispute_reason: [
        "quality",
        "damage",
        "provider_no_show",
        "customer_no_show",
        "price",
        "other",
      ],
      dispute_status: [
        "open",
        "in_review",
        "resolved_no_action",
        "resolved_partial_refund",
        "resolved_refund",
        "withdrawn",
      ],
      exception_kind: ["closed", "open"],
      invoicing_service: ["none", "ukko", "eezy", "other"],
      locale: ["fi", "sv", "en"],
      location_type: ["workshop", "mobile"],
      member_role: ["owner", "staff"],
      notification_channel: ["push", "email", "sms"],
      notification_status: ["pending", "sent", "failed", "skipped"],
      payment_provider: ["stripe", "fake"],
      payment_status: [
        "pending",
        "requires_action",
        "authorized",
        "captured",
        "canceled",
        "failed",
        "partially_refunded",
        "refunded",
      ],
      photo_kind: ["before", "after", "checklist", "damage", "dispute"],
      provider_kind: ["company", "individual"],
      provider_status: ["pending", "active", "suspended"],
    },
  },
} as const
