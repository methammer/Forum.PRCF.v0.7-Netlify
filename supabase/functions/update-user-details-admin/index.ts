import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';

type UserRole = 'USER' | 'MODERATOR' | 'ADMIN' | 'SUPER_ADMIN'; // Ensure these are uppercase
type UserStatus = 'pending_approval' | 'approved' | 'rejected';

interface Profile {
  id: string;
  role: UserRole | string; 
  status: UserStatus;
}

interface UpdateUserDetailsPayload {
  targetUserId: string;
  updates: {
    full_name?: string;
    username?: string;
    role?: UserRole | string; 
    status?: UserStatus;
  };
}

const supabaseUrl = Deno.env.get('SUPABASE_URL');
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

async function getProfile(supabaseAdmin: SupabaseClient, userId: string): Promise<Profile | null> {
  const { data, error } = await supabaseAdmin
    .from('profiles')
    .select('id, role, status')
    .eq('id', userId)
    .single();
  if (error) {
    console.error(`Edge Function (update-user-details-admin): Error fetching profile for ${userId}:`, error.message);
    return null;
  }
  return data as Profile;
}


serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (!supabaseUrl || !serviceRoleKey) {
    console.error('Edge Function (update-user-details-admin): Server configuration error: Missing Supabase credentials.');
    return new Response(JSON.stringify({ error: 'Server configuration error.' }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    });
  }

  let payload: UpdateUserDetailsPayload;
  try {
    payload = await req.json();
  } catch (error) {
    return new Response(JSON.stringify({ error: 'Invalid JSON payload: ' + error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    });
  }

  const { targetUserId, updates } = payload;

  if (!targetUserId || !updates || Object.keys(updates).length === 0) {
    return new Response(JSON.stringify({ error: 'Missing targetUserId or updates in payload.' }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    });
  }

  try {
    const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      console.warn('Edge Function (update-user-details-admin): Missing Authorization header.');
      return new Response(JSON.stringify({ error: 'Missing Authorization header.' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 401,
      });
    }
    const { data: { user: invokerUser }, error: invokerAuthError } = await supabaseAdmin.auth.getUser(authHeader.replace('Bearer ', ''));

    if (invokerAuthError || !invokerUser) {
      console.error('Edge Function (update-user-details-admin): Invoker auth error:', invokerAuthError?.message);
      return new Response(JSON.stringify({ error: 'Authentication failed for invoker.' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 401,
      });
    }

    const invokerProfile = await getProfile(supabaseAdmin, invokerUser.id);
    console.log(`Edge Function (update-user-details-admin): Invoker ID: ${invokerUser.id}, Raw Invoker Profile from DB: ${JSON.stringify(invokerProfile)}`);

    if (!invokerProfile || !invokerProfile.role) {
      console.error(`Edge Function (update-user-details-admin): Invoker profile not found or role is missing for ${invokerUser.id}. Profile: ${JSON.stringify(invokerProfile)}`);
      return new Response(JSON.stringify({ error: 'Invoker profile not found or role is missing.' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 403,
      });
    }

    const targetProfile = await getProfile(supabaseAdmin, targetUserId);
     console.log(`Edge Function (update-user-details-admin): Target User ID: ${targetUserId}, Raw Target Profile from DB: ${JSON.stringify(targetProfile)}`);
     console.log(`Edge Function (update-user-details-admin): Updates requested: ${JSON.stringify(updates)}`);


    if (!targetProfile || !targetProfile.role) {
      console.error(`Edge Function (update-user-details-admin): Target profile not found or role is missing for ${targetUserId}. Profile: ${JSON.stringify(targetProfile)}`);
      return new Response(JSON.stringify({ error: `Target user profile (ID: ${targetUserId}) not found or role is missing.` }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 404,
      });
    }

    const invokerRole = (typeof invokerProfile.role === 'string' ? invokerProfile.role.toUpperCase() : '') as UserRole;
    const targetRoleCurrent = (typeof targetProfile.role === 'string' ? targetProfile.role.toUpperCase() : '') as UserRole;
    
    const finalUpdates = { ...updates };
    let newRoleToSet: UserRole | undefined = undefined;
    if (finalUpdates.role && typeof finalUpdates.role === 'string') {
      newRoleToSet = finalUpdates.role.toUpperCase() as UserRole;
      finalUpdates.role = newRoleToSet; 
    }

    console.log(`Edge Function (update-user-details-admin): Normalized Invoker Role: ${invokerRole}, Normalized Current Target Role: ${targetRoleCurrent}, Normalized New Role to Set: ${newRoleToSet}`);

    if (invokerRole === 'SUPER_ADMIN') {
      if (invokerUser.id === targetUserId && newRoleToSet && newRoleToSet !== 'SUPER_ADMIN') {
        console.warn(`Edge Function (update-user-details-admin): SUPER_ADMIN ${invokerUser.id} attempted to demote self.`);
        return new Response(JSON.stringify({ error: 'Super Admins cannot demote themselves through this function.' }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 403,
        });
      }
    }
    else if (invokerRole === 'ADMIN') {
      // Rule 1: Admins cannot modify other Admins or Super Admins (unless it's themselves, covered by Rule 3).
      if (invokerUser.id !== targetUserId && (targetRoleCurrent === 'ADMIN' || targetRoleCurrent === 'SUPER_ADMIN')) {
        console.warn(`Edge Function (update-user-details-admin): ADMIN ${invokerUser.id} attempted to modify another ADMIN/SUPER_ADMIN ${targetUserId}.`);
        return new Response(JSON.stringify({ error: 'Admins cannot modify other Admins or Super Admins.' }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 403,
        });
      }

      // Rule 2: Admins cannot promote users to Super Admin.
      if (newRoleToSet === 'SUPER_ADMIN') {
        console.warn(`Edge Function (update-user-details-admin): ADMIN ${invokerUser.id} attempted to promote user ${targetUserId} to SUPER_ADMIN.`);
        return new Response(JSON.stringify({ error: 'Admins cannot promote users to Super Admin.' }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 403,
        });
      }
      
      // Rule 3: Admins cannot change their own role to a non-admin role.
      // (They also cannot promote themselves to SUPER_ADMIN due to Rule 2).
      // (Setting own role to ADMIN is a no-op for role change, but other fields might be updated).
      if (invokerUser.id === targetUserId && newRoleToSet && newRoleToSet !== 'ADMIN') {
         console.warn(`Edge Function (update-user-details-admin): ADMIN ${invokerUser.id} attempted to change own role to ${newRoleToSet}.`);
         return new Response(JSON.stringify({ error: 'Admins cannot change their own role to a non-admin role (USER or MODERATOR) via this function.' }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 403,
        });
      }
      // If an ADMIN is trying to update their own profile (e.g. full_name) but not changing their role,
      // or setting their role to ADMIN (no change), it should be allowed.
      // The above rules cover disallowed role changes.
    }
    else if (invokerRole === 'MODERATOR') {
      if (finalUpdates.role) { 
        console.warn(`Edge Function (update-user-details-admin): MODERATOR ${invokerUser.id} attempted to change role for ${targetUserId}.`);
        return new Response(JSON.stringify({ error: 'Moderators cannot change user roles.' }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 403,
        });
      }
      if (targetRoleCurrent !== 'USER') {
        console.warn(`Edge Function (update-user-details-admin): MODERATOR ${invokerUser.id} attempted to modify non-USER role ${targetUserId}.`);
        return new Response(JSON.stringify({ error: 'Moderators can only modify users with the "USER" role.' }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 403,
        });
      }
      const allowedUpdatesByModerator = ['status']; 
      for (const key in finalUpdates) {
        if (!allowedUpdatesByModerator.includes(key)) {
          console.warn(`Edge Function (update-user-details-admin): MODERATOR ${invokerUser.id} attempted to update restricted field '${key}' for ${targetUserId}.`);
          return new Response(JSON.stringify({ error: `Moderators cannot update field: ${key}` }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 403,
          });
        }
      }
    }
    else { 
      console.warn(`Edge Function (update-user-details-admin): Insufficient role ('${invokerRole}') for invoker ${invokerUser.id}.`);
      return new Response(JSON.stringify({ error: 'Permission denied. Insufficient role.' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 403,
      });
    }

    console.log(`Edge Function (update-user-details-admin): Permissions check passed for invoker ${invokerUser.id} (Role: ${invokerRole}) targeting user ${targetUserId}. Proceeding with update: ${JSON.stringify(finalUpdates)}`);
    const { data: updatedData, error: updateError } = await supabaseAdmin
      .from('profiles')
      .update(finalUpdates) 
      .eq('id', targetUserId)
      .select()
      .single();

    if (updateError) {
      console.error(`Edge Function (update-user-details-admin): Error updating profile ${targetUserId}:`, JSON.stringify(updateError));
      if (updateError.code === '23505' && updateError.message.includes('profiles_username_key')) {
        return new Response(JSON.stringify({ error: 'Username is already taken.', details: updateError.message }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 409,
        });
      }
      return new Response(JSON.stringify({ error: 'Failed to update profile.', details: updateError.message }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      });
    }

    console.log(`Edge Function (update-user-details-admin): User ${targetUserId} details updated successfully. New data: ${JSON.stringify(updatedData)}`);
    return new Response(JSON.stringify({ message: 'User details updated successfully.', data: updatedData }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });

  } catch (error) {
    console.error('Edge Function (update-user-details-admin): Unexpected error:', error.message, JSON.stringify(error));
    return new Response(JSON.stringify({ error: 'Internal server error: ' + error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    });
  }
});
