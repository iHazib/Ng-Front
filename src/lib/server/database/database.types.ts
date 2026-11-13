// Generated from the disposable migrated PostgreSQL database. Do not hand-edit.
export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[];
export type Database = { public: { Tables: {
  article_media: {
    Row: {
      article_id: string;
      media_id: string;
      position: number;
      id: string;
      kind: string;
    };
    Insert: {
      article_id: string;
      media_id: string;
      position: number;
      id?: string;
      kind?: string;
    };
    Update: Partial<Database["public"]["Tables"]["article_media"]["Insert"]>;
  };
  article_tags: {
    Row: {
      article_id: string;
      tag_id: string;
    };
    Insert: {
      article_id: string;
      tag_id: string;
    };
    Update: Partial<Database["public"]["Tables"]["article_tags"]["Insert"]>;
  };
  articles: {
    Row: {
      id: string;
      slug: string | null;
      title: string;
      excerpt: string | null;
      body: string | null;
      theme: string | null;
      status: Database["public"]["Enums"]["publication_status"];
      published_at: string | null;
      created_at: string;
      updated_at: string;
      author: string | null;
      seo_title: string | null;
      seo_description: string | null;
      revision: number;
      deleted_at: string | null;
      category_id: string | null;
    };
    Insert: {
      id?: string;
      slug?: string | null;
      title: string;
      excerpt?: string | null;
      body?: string | null;
      theme?: string | null;
      status?: Database["public"]["Enums"]["publication_status"];
      published_at?: string | null;
      created_at?: string;
      updated_at?: string;
      author?: string | null;
      seo_title?: string | null;
      seo_description?: string | null;
      revision?: number;
      deleted_at?: string | null;
      category_id?: string | null;
    };
    Update: Partial<Database["public"]["Tables"]["articles"]["Insert"]>;
  };
  audit_logs: {
    Row: {
      id: number;
      actor_id: string | null;
      occurred_at: string;
      table_name: string;
      record_key: string | null;
      operation: string;
      changed_columns: string[];
    };
    Insert: {
      actor_id?: string | null;
      occurred_at?: string;
      table_name: string;
      record_key?: string | null;
      operation: string;
      changed_columns?: string[];
    };
    Update: Partial<Database["public"]["Tables"]["audit_logs"]["Insert"]>;
  };
  brand_aliases: {
    Row: {
      id: string;
      brand_id: string;
      alias: string;
      normalized: string | null;
    };
    Insert: {
      id?: string;
      brand_id: string;
      alias: string;
    };
    Update: Partial<Database["public"]["Tables"]["brand_aliases"]["Insert"]>;
  };
  brands: {
    Row: {
      id: string;
      name: string;
      status: Database["public"]["Enums"]["publication_status"];
      created_at: string;
    };
    Insert: {
      id: string;
      name: string;
      status?: Database["public"]["Enums"]["publication_status"];
      created_at?: string;
    };
    Update: Partial<Database["public"]["Tables"]["brands"]["Insert"]>;
  };
  catalog_search_aliases: {
    Row: {
      id: string;
      product_id: string | null;
      category_id: string | null;
      brand_id: string | null;
      concern_id: string | null;
      product_type_id: string | null;
      alias: string;
      status: Database["public"]["Enums"]["review_status"];
      reviewed_by: string | null;
      reviewed_at: string | null;
    };
    Insert: {
      id?: string;
      product_id?: string | null;
      category_id?: string | null;
      brand_id?: string | null;
      concern_id?: string | null;
      product_type_id?: string | null;
      alias: string;
      status?: Database["public"]["Enums"]["review_status"];
      reviewed_by?: string | null;
      reviewed_at?: string | null;
    };
    Update: Partial<Database["public"]["Tables"]["catalog_search_aliases"]["Insert"]>;
  };
  categories: {
    Row: {
      id: string;
      parent_id: string | null;
      name: string;
      scope: Database["public"]["Enums"]["catalog_scope"] | null;
      status: Database["public"]["Enums"]["publication_status"];
    };
    Insert: {
      id: string;
      parent_id?: string | null;
      name: string;
      scope?: Database["public"]["Enums"]["catalog_scope"] | null;
      status?: Database["public"]["Enums"]["publication_status"];
    };
    Update: Partial<Database["public"]["Tables"]["categories"]["Insert"]>;
  };
  category_product_types: {
    Row: {
      category_id: string;
      product_type_id: string;
    };
    Insert: {
      category_id: string;
      product_type_id: string;
    };
    Update: Partial<Database["public"]["Tables"]["category_product_types"]["Insert"]>;
  };
  collection_products: {
    Row: {
      collection_id: string;
      product_id: string;
      position: number;
    };
    Insert: {
      collection_id: string;
      product_id: string;
      position: number;
    };
    Update: Partial<Database["public"]["Tables"]["collection_products"]["Insert"]>;
  };
  collections: {
    Row: {
      id: string;
      slug: string;
      name: string;
      status: Database["public"]["Enums"]["publication_status"];
    };
    Insert: {
      id?: string;
      slug: string;
      name: string;
      status?: Database["public"]["Enums"]["publication_status"];
    };
    Update: Partial<Database["public"]["Tables"]["collections"]["Insert"]>;
  };
  concerns: {
    Row: {
      id: string;
      name: string;
      claim_kind: string;
      active: boolean;
    };
    Insert: {
      id: string;
      name: string;
      claim_kind: string;
      active?: boolean;
    };
    Update: Partial<Database["public"]["Tables"]["concerns"]["Insert"]>;
  };
  deal_components: {
    Row: {
      deal_id: string;
      variant_id: string;
      quantity: number;
    };
    Insert: {
      deal_id: string;
      variant_id: string;
      quantity: number;
    };
    Update: Partial<Database["public"]["Tables"]["deal_components"]["Insert"]>;
  };
  deal_media: {
    Row: {
      id: string;
      deal_id: string;
      media_id: string;
      position: number;
      is_primary: boolean;
    };
    Insert: {
      id?: string;
      deal_id: string;
      media_id: string;
      position: number;
      is_primary?: boolean;
    };
    Update: Partial<Database["public"]["Tables"]["deal_media"]["Insert"]>;
  };
  deals: {
    Row: {
      id: string;
      name: string;
      slug: string | null;
      status: Database["public"]["Enums"]["publication_status"];
      price_minor: number | null;
      currency: string;
      description: string | null;
      starts_at: string | null;
      ends_at: string | null;
    };
    Insert: {
      id?: string;
      name: string;
      slug?: string | null;
      status?: Database["public"]["Enums"]["publication_status"];
      price_minor?: number | null;
      currency?: string;
      description?: string | null;
      starts_at?: string | null;
      ends_at?: string | null;
    };
    Update: Partial<Database["public"]["Tables"]["deals"]["Insert"]>;
  };
  editorial_categories: {
    Row: {
      id: string;
      name: string;
    };
    Insert: {
      id?: string;
      name: string;
    };
    Update: Partial<Database["public"]["Tables"]["editorial_categories"]["Insert"]>;
  };
  editorial_tags: {
    Row: {
      id: string;
      name: string;
    };
    Insert: {
      id?: string;
      name: string;
    };
    Update: Partial<Database["public"]["Tables"]["editorial_tags"]["Insert"]>;
  };
  evidence: {
    Row: {
      id: string;
      source_key: string | null;
      source_type: string;
      url: string | null;
      finding: string;
      region: string | null;
      product_version: string | null;
      accessed_on: string | null;
      status: Database["public"]["Enums"]["review_status"];
      reviewed_by: string | null;
      reviewed_at: string | null;
    };
    Insert: {
      id?: string;
      source_key?: string | null;
      source_type: string;
      url?: string | null;
      finding: string;
      region?: string | null;
      product_version?: string | null;
      accessed_on?: string | null;
      status?: Database["public"]["Enums"]["review_status"];
      reviewed_by?: string | null;
      reviewed_at?: string | null;
    };
    Update: Partial<Database["public"]["Tables"]["evidence"]["Insert"]>;
  };
  facet_definitions: {
    Row: {
      id: string;
      name: string;
      kind: Database["public"]["Enums"]["facet_kind"];
      active: boolean;
    };
    Insert: {
      id: string;
      name: string;
      kind: Database["public"]["Enums"]["facet_kind"];
      active?: boolean;
    };
    Update: Partial<Database["public"]["Tables"]["facet_definitions"]["Insert"]>;
  };
  facet_scopes: {
    Row: {
      facet_id: string;
      scope: Database["public"]["Enums"]["catalog_scope"];
    };
    Insert: {
      facet_id: string;
      scope: Database["public"]["Enums"]["catalog_scope"];
    };
    Update: Partial<Database["public"]["Tables"]["facet_scopes"]["Insert"]>;
  };
  facet_values: {
    Row: {
      id: string;
      facet_id: string;
      label: string;
    };
    Insert: {
      id: string;
      facet_id: string;
      label: string;
    };
    Update: Partial<Database["public"]["Tables"]["facet_values"]["Insert"]>;
  };
  factory_set_contents: {
    Row: {
      id: string;
      set_variant_id: string;
      position: number;
      name: string;
      quantity: number;
      size_value: number | null;
      size_unit: string | null;
      shade: string | null;
      evidence_id: string | null;
    };
    Insert: {
      id?: string;
      set_variant_id: string;
      position: number;
      name: string;
      quantity: number;
      size_value?: number | null;
      size_unit?: string | null;
      shade?: string | null;
      evidence_id?: string | null;
    };
    Update: Partial<Database["public"]["Tables"]["factory_set_contents"]["Insert"]>;
  };
  homepage_media: {
    Row: {
      id: string;
      homepage_id: string;
      media_id: string;
    };
    Insert: {
      id?: string;
      homepage_id: string;
      media_id: string;
    };
    Update: Partial<Database["public"]["Tables"]["homepage_media"]["Insert"]>;
  };
  homepage_selections: {
    Row: {
      id: string;
      section: string;
      position: number;
      status: Database["public"]["Enums"]["publication_status"];
      product_id: string | null;
      article_id: string | null;
      category_id: string | null;
      brand_id: string | null;
      media_id: string | null;
      heading: string | null;
      body: string | null;
      cta_path: string | null;
      slide_theme: string | null;
      retired_at: string | null;
      deal_id: string | null;
    };
    Insert: {
      id?: string;
      section: string;
      position: number;
      status?: Database["public"]["Enums"]["publication_status"];
      product_id?: string | null;
      article_id?: string | null;
      category_id?: string | null;
      brand_id?: string | null;
      media_id?: string | null;
      heading?: string | null;
      body?: string | null;
      cta_path?: string | null;
      slide_theme?: string | null;
      retired_at?: string | null;
      deal_id?: string | null;
    };
    Update: Partial<Database["public"]["Tables"]["homepage_selections"]["Insert"]>;
  };
  import_batches: {
    Row: {
      id: string;
      source_sha256: string;
      contract_version: string;
      contract_sha256: string;
      created_at: string;
      created_by: string | null;
    };
    Insert: {
      id?: string;
      source_sha256: string;
      contract_version: string;
      contract_sha256: string;
      created_at?: string;
      created_by?: string | null;
    };
    Update: Partial<Database["public"]["Tables"]["import_batches"]["Insert"]>;
  };
  import_records: {
    Row: {
      id: string;
      batch_id: string;
      source_row: number;
      original_sku: string | null;
      variant_id: string | null;
      raw_fields: Json;
      mapping: Json;
      source_quantity: number | null;
      source_cost_minor: number | null;
      source_target_minor: number | null;
      source_minimum_minor: number | null;
      source_market_minor: number | null;
      state: string;
      flags: Json;
    };
    Insert: {
      id?: string;
      batch_id: string;
      source_row: number;
      original_sku?: string | null;
      variant_id?: string | null;
      raw_fields: Json;
      mapping: Json;
      source_quantity?: number | null;
      source_cost_minor?: number | null;
      source_target_minor?: number | null;
      source_minimum_minor?: number | null;
      source_market_minor?: number | null;
      state: string;
      flags?: Json;
    };
    Update: Partial<Database["public"]["Tables"]["import_records"]["Insert"]>;
  };
  inventory_balances: {
    Row: {
      variant_id: string;
      on_hand: number;
      reserved: number;
      reconciled_at: string | null;
    };
    Insert: {
      variant_id: string;
      on_hand?: number;
      reserved?: number;
      reconciled_at?: string | null;
    };
    Update: Partial<Database["public"]["Tables"]["inventory_balances"]["Insert"]>;
  };
  inventory_counts: {
    Row: {
      id: string;
      variant_id: string;
      previous_count: number;
      counted: number;
      actor_id: string;
      recorded_at: string;
      operation_id: string;
    };
    Insert: {
      id?: string;
      variant_id: string;
      previous_count: number;
      counted: number;
      actor_id: string;
      recorded_at?: string;
      operation_id: string;
    };
    Update: Partial<Database["public"]["Tables"]["inventory_counts"]["Insert"]>;
  };
  inventory_movements: {
    Row: {
      id: string;
      variant_id: string;
      delta: number;
      reason: string;
      idempotency_key: string;
      order_id: string | null;
      actor_id: string | null;
      created_at: string;
    };
    Insert: {
      id?: string;
      variant_id: string;
      delta: number;
      reason: string;
      idempotency_key: string;
      order_id?: string | null;
      actor_id?: string | null;
      created_at?: string;
    };
    Update: Partial<Database["public"]["Tables"]["inventory_movements"]["Insert"]>;
  };
  inventory_reservations: {
    Row: {
      id: string;
      order_id: string;
      variant_id: string;
      quantity: number;
      state: string;
      expires_at: string;
      idempotency_key: string;
      created_at: string;
    };
    Insert: {
      id?: string;
      order_id: string;
      variant_id: string;
      quantity: number;
      state?: string;
      expires_at: string;
      idempotency_key: string;
      created_at?: string;
    };
    Update: Partial<Database["public"]["Tables"]["inventory_reservations"]["Insert"]>;
  };
  media_assets: {
    Row: {
      id: string;
      provider: string;
      cloudinary_public_id: string | null;
      cloudinary_version: number | null;
      cloudinary_resource_type: string | null;
      cloudinary_format: string | null;
      private_bucket: string | null;
      private_path: string | null;
      width: number | null;
      height: number | null;
      alt: string | null;
      status: Database["public"]["Enums"]["review_status"];
      created_at: string;
      cloudinary_asset_id: string | null;
      cloudinary_cloud_name: string | null;
      media_environment: string | null;
      content_sha256: string | null;
      byte_size: number | null;
      lifecycle: string;
    };
    Insert: {
      id?: string;
      provider: string;
      cloudinary_public_id?: string | null;
      cloudinary_version?: number | null;
      cloudinary_resource_type?: string | null;
      cloudinary_format?: string | null;
      private_bucket?: string | null;
      private_path?: string | null;
      width?: number | null;
      height?: number | null;
      alt?: string | null;
      status?: Database["public"]["Enums"]["review_status"];
      created_at?: string;
      cloudinary_asset_id?: string | null;
      cloudinary_cloud_name?: string | null;
      media_environment?: string | null;
      content_sha256?: string | null;
      byte_size?: number | null;
      lifecycle?: string;
    };
    Update: Partial<Database["public"]["Tables"]["media_assets"]["Insert"]>;
  };
  media_workflows: {
    Row: {
      media_id: string;
      product_id: string | null;
      variant_id: string | null;
      private_path: string;
      expected_public_id: string;
      replace_association_id: string | null;
      replace_media_id: string | null;
      association_id: string | null;
      reviewed_by: string | null;
      reviewed_at: string | null;
      error_code: string | null;
      updated_at: string;
      created_at: string;
      article_id: string | null;
      homepage_id: string | null;
      content_kind: string | null;
      review_id: string | null;
      payment_order_id: string | null;
      deal_id: string | null;
    };
    Insert: {
      media_id: string;
      product_id?: string | null;
      variant_id?: string | null;
      private_path: string;
      expected_public_id: string;
      replace_association_id?: string | null;
      replace_media_id?: string | null;
      association_id?: string | null;
      reviewed_by?: string | null;
      reviewed_at?: string | null;
      error_code?: string | null;
      updated_at?: string;
      created_at?: string;
      article_id?: string | null;
      homepage_id?: string | null;
      content_kind?: string | null;
      review_id?: string | null;
      payment_order_id?: string | null;
      deal_id?: string | null;
    };
    Update: Partial<Database["public"]["Tables"]["media_workflows"]["Insert"]>;
  };
  option_axes: {
    Row: {
      id: string;
      name: string;
    };
    Insert: {
      id: string;
      name: string;
    };
    Update: Partial<Database["public"]["Tables"]["option_axes"]["Insert"]>;
  };
  option_values: {
    Row: {
      id: string;
      axis_id: string;
      label: string;
    };
    Insert: {
      id: string;
      axis_id: string;
      label: string;
    };
    Update: Partial<Database["public"]["Tables"]["option_values"]["Insert"]>;
  };
  order_item_components: {
    Row: {
      order_item_id: string;
      variant_id: string;
      quantity: number;
    };
    Insert: {
      order_item_id: string;
      variant_id: string;
      quantity: number;
    };
    Update: Partial<Database["public"]["Tables"]["order_item_components"]["Insert"]>;
  };
  order_items: {
    Row: {
      id: string;
      order_id: string;
      variant_id: string | null;
      deal_id: string | null;
      name_snapshot: string;
      sku_snapshot: string | null;
      quantity: number;
      unit_price_minor: number;
      line_total_minor: number;
    };
    Insert: {
      id?: string;
      order_id: string;
      variant_id?: string | null;
      deal_id?: string | null;
      name_snapshot: string;
      sku_snapshot?: string | null;
      quantity: number;
      unit_price_minor: number;
      line_total_minor: number;
    };
    Update: Partial<Database["public"]["Tables"]["order_items"]["Insert"]>;
  };
  orders: {
    Row: {
      id: string;
      customer_id: string | null;
      status: string;
      currency: string;
      subtotal_minor: number;
      shipping_minor: number | null;
      discount_minor: number;
      total_minor: number | null;
      contact_email: string | null;
      contact_phone: string | null;
      delivery_name: string | null;
      address: Json | null;
      created_at: string;
      updated_at: string;
    };
    Insert: {
      id?: string;
      customer_id?: string | null;
      status?: string;
      currency?: string;
      subtotal_minor?: number;
      shipping_minor?: number | null;
      discount_minor?: number;
      total_minor?: number | null;
      contact_email?: string | null;
      contact_phone?: string | null;
      delivery_name?: string | null;
      address?: Json | null;
      created_at?: string;
      updated_at?: string;
    };
    Update: Partial<Database["public"]["Tables"]["orders"]["Insert"]>;
  };
  product_categories: {
    Row: {
      product_id: string;
      category_id: string;
    };
    Insert: {
      product_id: string;
      category_id: string;
    };
    Update: Partial<Database["public"]["Tables"]["product_categories"]["Insert"]>;
  };
  product_checks: {
    Row: {
      product_id: string;
      code: string;
      approved: boolean;
      evidence_id: string | null;
      approved_by: string | null;
      approved_at: string | null;
    };
    Insert: {
      product_id: string;
      code: string;
      approved?: boolean;
      evidence_id?: string | null;
      approved_by?: string | null;
      approved_at?: string | null;
    };
    Update: Partial<Database["public"]["Tables"]["product_checks"]["Insert"]>;
  };
  product_concerns: {
    Row: {
      product_id: string;
      concern_id: string;
      evidence_id: string | null;
      status: Database["public"]["Enums"]["review_status"];
      qualification: string;
    };
    Insert: {
      product_id: string;
      concern_id: string;
      evidence_id?: string | null;
      status?: Database["public"]["Enums"]["review_status"];
      qualification: string;
    };
    Update: Partial<Database["public"]["Tables"]["product_concerns"]["Insert"]>;
  };
  product_facets: {
    Row: {
      id: string;
      product_id: string;
      variant_id: string | null;
      facet_id: string;
      kind: Database["public"]["Enums"]["facet_kind"];
      option_id: string | null;
      integer_value: number | null;
      decimal_value: number | null;
      boolean_value: boolean | null;
      unit: string | null;
      evidence_id: string | null;
      status: Database["public"]["Enums"]["review_status"];
    };
    Insert: {
      id?: string;
      product_id: string;
      variant_id?: string | null;
      facet_id: string;
      kind: Database["public"]["Enums"]["facet_kind"];
      option_id?: string | null;
      integer_value?: number | null;
      decimal_value?: number | null;
      boolean_value?: boolean | null;
      unit?: string | null;
      evidence_id?: string | null;
      status?: Database["public"]["Enums"]["review_status"];
    };
    Update: Partial<Database["public"]["Tables"]["product_facets"]["Insert"]>;
  };
  product_media: {
    Row: {
      id: string;
      product_id: string;
      variant_id: string | null;
      media_id: string;
      position: number;
      is_primary: boolean;
    };
    Insert: {
      id?: string;
      product_id: string;
      variant_id?: string | null;
      media_id: string;
      position: number;
      is_primary?: boolean;
    };
    Update: Partial<Database["public"]["Tables"]["product_media"]["Insert"]>;
  };
  product_types: {
    Row: {
      id: string;
      name: string;
    };
    Insert: {
      id: string;
      name: string;
    };
    Update: Partial<Database["public"]["Tables"]["product_types"]["Insert"]>;
  };
  products: {
    Row: {
      id: string;
      name: string;
      slug: string | null;
      brand_id: string | null;
      category_id: string | null;
      product_type_id: string | null;
      status: Database["public"]["Enums"]["publication_status"];
      description: string | null;
      usage: string | null;
      identity_confirmed: boolean;
      created_at: string;
      updated_at: string;
      revision: number;
      search_vector: string | null;
      key_benefits: string | null;
    };
    Insert: {
      id?: string;
      name: string;
      slug?: string | null;
      brand_id?: string | null;
      category_id?: string | null;
      product_type_id?: string | null;
      status?: Database["public"]["Enums"]["publication_status"];
      description?: string | null;
      usage?: string | null;
      identity_confirmed?: boolean;
      created_at?: string;
      updated_at?: string;
      revision?: number;
      key_benefits?: string | null;
    };
    Update: Partial<Database["public"]["Tables"]["products"]["Insert"]>;
  };
  publication_requirements: {
    Row: {
      scope: Database["public"]["Enums"]["catalog_scope"];
      code: string;
      kind: string;
      description: string;
    };
    Insert: {
      scope: Database["public"]["Enums"]["catalog_scope"];
      code: string;
      kind: string;
      description: string;
    };
    Update: Partial<Database["public"]["Tables"]["publication_requirements"]["Insert"]>;
  };
  refunds: {
    Row: {
      id: string;
      sale_id: string;
      amount_minor: number;
      reason: string;
      idempotency_key: string;
      occurred_at: string;
    };
    Insert: {
      id?: string;
      sale_id: string;
      amount_minor: number;
      reason: string;
      idempotency_key: string;
      occurred_at?: string;
    };
    Update: Partial<Database["public"]["Tables"]["refunds"]["Insert"]>;
  };
  review_media: {
    Row: {
      id: string;
      review_id: string;
      media_id: string;
      position: number;
    };
    Insert: {
      id?: string;
      review_id: string;
      media_id: string;
      position: number;
    };
    Update: Partial<Database["public"]["Tables"]["review_media"]["Insert"]>;
  };
  review_moderation_events: {
    Row: {
      id: number;
      review_id: string;
      action: string;
      revision: number;
      actor_id: string | null;
      occurred_at: string;
    };
    Insert: {
      review_id: string;
      action: string;
      revision: number;
      actor_id?: string | null;
      occurred_at?: string;
    };
    Update: Partial<Database["public"]["Tables"]["review_moderation_events"]["Insert"]>;
  };
  review_private: {
    Row: {
      review_id: string;
      user_id: string | null;
      order_item_id: string | null;
      moderation_note: string | null;
      approved_by: string | null;
      approved_at: string | null;
      email: string | null;
      submission_hash: string | null;
      payload_hash: string | null;
    };
    Insert: {
      review_id: string;
      user_id?: string | null;
      order_item_id?: string | null;
      moderation_note?: string | null;
      approved_by?: string | null;
      approved_at?: string | null;
      email?: string | null;
      submission_hash?: string | null;
      payload_hash?: string | null;
    };
    Update: Partial<Database["public"]["Tables"]["review_private"]["Insert"]>;
  };
  reviews: {
    Row: {
      id: string;
      product_id: string;
      display_name: string;
      rating: number;
      body: string;
      status: Database["public"]["Enums"]["review_status"];
      created_at: string;
      title: string | null;
      hidden_at: string | null;
      revision: number;
      updated_at: string;
      submission_complete: boolean;
    };
    Insert: {
      id?: string;
      product_id: string;
      display_name: string;
      rating: number;
      body: string;
      status?: Database["public"]["Enums"]["review_status"];
      created_at?: string;
      title?: string | null;
      hidden_at?: string | null;
      revision?: number;
      updated_at?: string;
      submission_complete?: boolean;
    };
    Update: Partial<Database["public"]["Tables"]["reviews"]["Insert"]>;
  };
  sales: {
    Row: {
      id: string;
      order_id: string;
      amount_minor: number;
      currency: string;
      external_reference: string | null;
      idempotency_key: string;
      occurred_at: string;
    };
    Insert: {
      id?: string;
      order_id: string;
      amount_minor: number;
      currency?: string;
      external_reference?: string | null;
      idempotency_key: string;
      occurred_at?: string;
    };
    Update: Partial<Database["public"]["Tables"]["sales"]["Insert"]>;
  };
  shipment_items: {
    Row: {
      shipment_id: string;
      order_item_id: string;
      quantity: number;
    };
    Insert: {
      shipment_id: string;
      order_item_id: string;
      quantity: number;
    };
    Update: Partial<Database["public"]["Tables"]["shipment_items"]["Insert"]>;
  };
  shipments: {
    Row: {
      id: string;
      order_id: string;
      provider: string | null;
      tracking_reference: string | null;
      status: string;
      created_at: string;
      dispatched_at: string | null;
      delivered_at: string | null;
    };
    Insert: {
      id?: string;
      order_id: string;
      provider?: string | null;
      tracking_reference?: string | null;
      status?: string;
      created_at?: string;
      dispatched_at?: string | null;
      delivered_at?: string | null;
    };
    Update: Partial<Database["public"]["Tables"]["shipments"]["Insert"]>;
  };
  sku_aliases: {
    Row: {
      alias: string;
      variant_id: string;
      collision_key: string | null;
    };
    Insert: {
      alias: string;
      variant_id: string;
    };
    Update: Partial<Database["public"]["Tables"]["sku_aliases"]["Insert"]>;
  };
  variant_options: {
    Row: {
      variant_id: string;
      axis_id: string;
      value_id: string;
    };
    Insert: {
      variant_id: string;
      axis_id: string;
      value_id: string;
    };
    Update: Partial<Database["public"]["Tables"]["variant_options"]["Insert"]>;
  };
  variant_prices: {
    Row: {
      variant_id: string;
      currency: string;
      amount_minor: number;
      approved: boolean;
      updated_at: string;
    };
    Insert: {
      variant_id: string;
      currency?: string;
      amount_minor: number;
      approved?: boolean;
      updated_at?: string;
    };
    Update: Partial<Database["public"]["Tables"]["variant_prices"]["Insert"]>;
  };
  variants: {
    Row: {
      id: string;
      product_id: string;
      original_sku: string;
      sku_key: string | null;
      label: string | null;
      status: Database["public"]["Enums"]["publication_status"];
      sellable_kind: string;
      identity_confirmed: boolean;
      created_at: string;
    };
    Insert: {
      id?: string;
      product_id: string;
      original_sku: string;
      label?: string | null;
      status?: Database["public"]["Enums"]["publication_status"];
      sellable_kind?: string;
      identity_confirmed?: boolean;
      created_at?: string;
    };
    Update: Partial<Database["public"]["Tables"]["variants"]["Insert"]>;
  };
}; Enums: {
  catalog_scope: "skincare" | "makeup" | "bath-body" | "hair-care" | "personal-fragrance" | "home-fragrance" | "cutlery";
  facet_kind: "enum" | "reference" | "integer" | "decimal" | "boolean" | "quantity";
  publication_status: "draft" | "published" | "archived";
  review_status: "pending" | "approved" | "rejected";
}; }; };
export type TableName = keyof Database["public"]["Tables"];
export type Row<T extends TableName> = Database["public"]["Tables"][T]["Row"];
