import type { Row } from '@/lib/server/database/database.types';
export type SearchRow={product_id:string;variant_id:string;original_sku:string;name:string;status:string;price_minor?:number|null;stock?:number|null;media_id?:string|null};
export type References={
 brands:Row<'brands'>[];categories:Row<'categories'>[];product_types:Row<'product_types'>[];category_product_types:Row<'category_product_types'>[];
 facet_definitions:Row<'facet_definitions'>[];facet_scopes:Row<'facet_scopes'>[];facet_values:Row<'facet_values'>[];concerns:Row<'concerns'>[];
 option_axes:Row<'option_axes'>[];option_values:Row<'option_values'>[];publication_requirements:Row<'publication_requirements'>[];
};
export type Variant=Row<'variants'>&{variant_prices:Row<'variant_prices'>|null;inventory_balances:Row<'inventory_balances'>|null;variant_options:Row<'variant_options'>[]};
export type Detail={product:Row<'products'>;variants:Variant[];sources:{original_sku:string;raw_fields:unknown;mapping:unknown;source_quantity:number|null;flags:unknown;state:string}[];
 workflows:{media_id:string;variant_id:string|null;association_id:string|null;media_assets:Row<'media_assets'>}[];
 associations:Row<'product_media'>[];facets:(Row<'product_facets'>&{evidence:Row<'evidence'>;facet_values?:{label:string}|null})[];concerns:(Row<'product_concerns'>&{evidence:Row<'evidence'>})[];
 checks:Row<'product_checks'>[];features:{id:string;position:number;status:string}[];report:{essential_blockers:string[];optional_enrichment:string[];concern_research:string;specific_issues?:string[];daily_editor_version?:number;discovery_editor_version?:number};
};
export type InitialImage={key:string;filename:string;sha256:string;exactSku:string|null;variantId:string|null;productId:string|null};
