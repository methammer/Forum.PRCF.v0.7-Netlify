import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';

interface DeleteUserPayload {
  userIdToDelete: string;
}

// IMPORTANT: These environment variables must be set in your Supabase project's Edge Function settings
const supabaseUrl = Deno.env.get('SUPABASE_URL');
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

if (!supabaseUrl || !serviceRoleKey) {
  console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY environment variables.');
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*', // Or your specific frontend URL
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

serve(async (req: Request) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (!supabaseUrl || !serviceRoleKey) {
    return new Response(JSON.stringify({ error: 'Server configuration error: Missing Supabase credentials.' }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    });
  }
  
  let payload: DeleteUserPayload;
  try {
    payload = await req.json();
  } catch (error) {
    return new Response(JSON.stringify({ error: 'Invalid JSON payload: ' + error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    });
  }

  const { userIdToDelete } = payload;

  if (!userIdToDelete) {
    return new Response(JSON.stringify({ error: 'Missing required field: userIdToDelete is required.' }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    });
  }

  try {
    const supabaseAdmin: SupabaseClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    // Delete the user from auth.users
    // The corresponding profile in public.profiles should be deleted automatically
    // if `ON DELETE CASCADE` is set on the foreign key from `profiles.id` to `auth.users.id`.
    // (This is typically the case with the Supabase starter template).
    const { error: deleteError } = await supabaseAdmin.auth.admin.deleteUser(userIdToDelete);

    if (deleteError) {
      console.error(`Supabase auth.admin.deleteUser error for user ${userIdToDelete}:`, deleteError);
      // Check if the error is because the user does not exist (e.g., already deleted)
      if (deleteError.message.toLowerCase().includes('user not found')) {
         return new Response(JSON.stringify({ error: `User not found: ${deleteError.message}` }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 404, // Not Found
        });
      }
      return new Response(JSON.stringify({ error: `Auth error: ${deleteError.message}` }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: deleteError.status || 500,
      });
    }

    return new Response(JSON.stringify({ message: 'User deleted successfully', userId: userIdToDelete }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200, // OK
    });

  } catch (error) {
    console.error('Unexpected error in Edge Function:', error);
    return new Response(JSON.stringify({ error: 'Internal server error: ' + error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    });
  }
});
