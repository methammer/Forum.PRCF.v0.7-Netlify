import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient, SupabaseClient, PostgrestError } from 'https://esm.sh/@supabase/supabase-js@2';

interface CreateUserPayload {
  email: string;
  password?: string;
  full_name: string;
  username: string;
  role: 'USER' | 'MODERATOR' | 'ADMIN' | 'SUPER_ADMIN'; // This is the role intended, but profile.role will default to USER
}

const supabaseUrl = Deno.env.get('SUPABASE_URL');
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

if (!supabaseUrl || !serviceRoleKey) {
  console.error('CRITICAL: Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY environment variables in Edge Function.');
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (!supabaseUrl || !serviceRoleKey) {
    console.error('Edge Function: Server configuration error: Missing Supabase credentials.');
    return new Response(JSON.stringify({ error: 'Server configuration error: Missing Supabase credentials.' }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    });
  }
  
  let payload: CreateUserPayload;
  try {
    payload = await req.json();
  } catch (error) {
    console.error('Edge Function: Invalid JSON payload:', error.message);
    return new Response(JSON.stringify({ error: 'Invalid JSON payload: ' + error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    });
  }

  // The 'role' from payload is noted, but we won't directly set it on profile update
  // to avoid conflict with the 'prevent_profile_id_role_change' trigger.
  // The 'handle_new_user' trigger will set the default role (e.g., 'USER').
  // If a different role was intended (e.g. admin creating another admin),
  // it must be set via a subsequent call to 'update-user-details-admin'.
  const { email, password, full_name, username } = payload;

  if (!email || !password || !full_name || !username) {
    console.error('Edge Function: Missing required fields in payload (excluding role for this check):', payload);
    return new Response(JSON.stringify({ error: 'Missing required fields: email, password, full_name, username are required.' }), {
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

    console.log('Edge Function: Attempting to create user in auth:', email);
    const { data: authUserResponse, error: authError } = await supabaseAdmin.auth.admin.createUser({
      email: email,
      password: password,
      email_confirm: true, 
    });

    if (authError) {
      console.error('Edge Function: Supabase auth.admin.createUser error:', JSON.stringify(authError, null, 2));
      let errorMessage = `Auth error: ${authError.message}`;
      let statusCode = authError.status || 400;

      if (authError.message?.toLowerCase().includes('unique constraint') && authError.message?.toLowerCase().includes('email')) {
        errorMessage = "Cette adresse e-mail est déjà utilisée par un autre compte.";
        statusCode = 409;
      } else if (authError.message?.toLowerCase().includes('password should be at least 6 characters')) {
        errorMessage = "Le mot de passe doit contenir au moins 6 caractères.";
        statusCode = 400;
      }
      return new Response(JSON.stringify({ error: errorMessage, details: authError }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: statusCode,
      });
    }

    if (!authUserResponse || !authUserResponse.user) {
      console.error('Edge Function: User creation did not return a user object.');
      return new Response(JSON.stringify({ error: 'User creation failed: No user object returned from auth.' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      });
    }

    const newUserId = authUserResponse.user.id;
    console.log(`Edge Function: User ${newUserId} created in auth. Original user object:`, authUserResponse.user);
    
    console.log(`Edge Function: Attempting to explicitly re-confirm email for user ${newUserId}.`);
    const { data: updatedUserResponse, error: updateUserError } = await supabaseAdmin.auth.admin.updateUserById(
      newUserId,
      { email_confirm: true }
    );

    if (updateUserError) {
      console.error(`Edge Function: Error explicitly re-confirming email for user ${newUserId}:`, JSON.stringify(updateUserError, null, 2));
    } else {
      console.log(`Edge Function: Email explicitly re-confirmed for user ${newUserId}. User object after update:`, updatedUserResponse?.user);
    }

    console.log(`Edge Function: Attempting to update profile for user ${newUserId}. Role will be set by default by 'handle_new_user' trigger.`);
    // IMPORTANT: We DO NOT set 'role' here. The 'handle_new_user' trigger ensures the profile is created
    // with the default role (e.g., 'USER'). The 'prevent_profile_id_role_change' trigger
    // would block a direct role update here anyway.
    // If a specific role other than default is needed, it must be set via 'update-user-details-admin'.
    const profileUpdates = {
        full_name: full_name,
        username: username,
        status: 'approved', // Admins create users as approved by default
    };

    const { data: profileData, error: profileError } = await supabaseAdmin
      .from('profiles')
      .update(profileUpdates)
      .eq('id', newUserId)
      .select('id, username, full_name, role, status') // Select the actual data including the default role
      .single(); 

    if (profileError) {
      const err = profileError as any; 
      console.error(`Edge Function: Profile update error for user ${newUserId}. Raw error object:`, JSON.stringify(err, null, 2));
      console.log(`Edge Function: profileError properties: code='${err.code}', message='${err.message}', details='${err.details}', hint='${err.hint}'`);

      let errorMessage = `Erreur lors de la mise à jour du profil: ${err.message || 'Erreur inconnue'}. L'utilisateur a été créé dans l'authentification mais la mise à jour du profil a échoué.`;
      let statusCode = 500; 

      if (err.code && String(err.code) === '23505') { // Unique violation
        statusCode = 409; 
        if (err.message?.toLowerCase().includes('profiles_username_key') || err.details?.toLowerCase().includes('username')) {
            errorMessage = "Échec de la mise à jour du profil : ce nom d'utilisateur est déjà pris.";
        } else if (err.message?.toLowerCase().includes('profiles_email_key') || err.details?.toLowerCase().includes('email')) {
            // Note: email is usually unique in auth.users, this would be for profiles.email if it existed and was unique
            errorMessage = "Échec de la mise à jour du profil : cette adresse e-mail est déjà prise dans les profils.";
        } else {
            errorMessage = "Échec de la mise à jour du profil : une valeur unique est déjà utilisée (code 23505).";
        }
      } else if (err.code) { 
        errorMessage = `Erreur de mise à jour du profil: ${err.message} (Code: ${err.code})`;
        statusCode = (err as PostgrestError).status || 500;
      }
      
      console.log(`Edge Function: Determined statusCode: ${statusCode}, errorMessage: ${errorMessage}. PREPARING TO SEND THIS RESPONSE.`);
      return new Response(JSON.stringify({ error: errorMessage, details: profileError }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: statusCode,
      });
    }

    console.log(`Edge Function: Profile for user ${newUserId} updated successfully. Final profile data:`, profileData);
    return new Response(JSON.stringify({ message: 'User created and profile updated successfully', userId: newUserId, profile: profileData }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 201,
    });

  } catch (error) {
    console.error('Edge Function: Unexpected error in main try-catch block:', error, JSON.stringify(error, null, 2));
    return new Response(JSON.stringify({ error: 'Internal server error: ' + error.message, details: error }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    });
  }
});
