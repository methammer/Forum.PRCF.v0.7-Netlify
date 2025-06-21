import { serve } from "https://deno.land/std@0.192.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";

// Define CORS headers locally
const corsHeaders = {
  'Access-Control-Allow-Origin': '*', // Adjust to your frontend URL in production
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

console.log("admin-send-password-reset function initializing");

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    console.log("OPTIONS request received");
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false,
        },
      }
    );

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      console.error("Missing Authorization header");
      return new Response(JSON.stringify({ error: "Missing Authorization header" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    
    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: userError } = await supabaseAdmin.auth.getUser(token);

    if (userError || !user) {
      console.error("Invalid or expired token:", userError?.message);
      return new Response(JSON.stringify({ error: "Invalid or expired token" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Check user's role (requires a 'profiles' table or similar with role info)
    const { data: profile, error: profileError } = await supabaseAdmin
      .from('profiles')
      .select('role')
      .eq('id', user.id)
      .single();

    if (profileError || !profile || !['ADMIN', 'SUPER_ADMIN'].includes(profile.role)) {
      console.error("User does not have admin privileges:", profileError?.message || "Role not admin/super_admin");
      return new Response(JSON.stringify({ error: "Insufficient permissions" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    
    const { email: targetUserEmail } = await req.json();

    if (!targetUserEmail) {
      console.error("Target user email is required");
      return new Response(JSON.stringify({ error: "Target user email is required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const appSiteUrl = Deno.env.get("APP_SITE_URL");
    if (!appSiteUrl) {
      console.error("APP_SITE_URL environment variable is not set for the Edge Function.");
      return new Response(JSON.stringify({ error: "Server configuration error: APP_SITE_URL not set." }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    
    const redirectTo = `${appSiteUrl}/modifier-mot-de-passe`;
    console.log(`Attempting to send password reset for ${targetUserEmail}, redirectTo: ${redirectTo}`);

    const { error: resetError } = await supabaseAdmin.auth.resetPasswordForEmail(
      targetUserEmail,
      { redirectTo }
    );

    if (resetError) {
      console.error("Error sending password reset email:", resetError.message);
      return new Response(JSON.stringify({ error: resetError.message || "Failed to send password reset email." }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    console.log(`Password reset email initiated for ${targetUserEmail}`);
    return new Response(JSON.stringify({ message: "Password reset email sent successfully." }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (error) {
    console.error("Unexpected error in admin-send-password-reset function:", error.message);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
