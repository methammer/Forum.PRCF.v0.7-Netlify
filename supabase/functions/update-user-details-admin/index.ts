import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';

type UserRole = 'USER' | 'MODERATOR' | 'ADMIN' | 'SUPER_ADMIN';
type UserStatus = 'pending_approval' | 'approved' | 'rejected';

interface Profile {
  id: string;
  role: UserRole | string; // Role from DB might not be strictly typed yet
  status: UserStatus;
}

interface UpdateUserDetailsPayload {
  targetUserId: string;
  updates: {
    full_name?: string;
    username?: string;
    role?: UserRole | string; // Expect UPPERCASE from client, will be validated
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
  // The role from the DB should ideally be consistently UPPERCASE.
  // If it's not, this function should reflect that or it should be transformed upon retrieval.
  // For now, we assume it might be mixed case and handle uppercasing during permission checks.
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
    console.warn('Edge Function (update-user-details-admin): Invalid JSON payload received:', error.message);
    return new Response(JSON.stringify({ error: 'Invalid JSON payload: ' + error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    });
  }

  const { targetUserId, updates } = payload;

  if (!targetUserId || !updates || Object.keys(updates).length === 0) {
    console.warn('Edge Function (update-user-details-admin): Missing targetUserId or updates in payload.');
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
    console.log(`Edge Function (update-user-details-admin): Invoker ID: ${invokerUser.id}, Invoker Profile: ${JSON.stringify(invokerProfile)}`);

    if (!invokerProfile || !invokerProfile.role) {
      console.error(`Edge Function (update-user-details-admin): Invoker profile not found or role is missing for ${invokerUser.id}. Profile: ${JSON.stringify(invokerProfile)}`);
      return new Response(JSON.stringify({ error: 'Invoker profile not found or role is missing.' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 403,
      });
    }

    const targetProfile = await getProfile(supabaseAdmin, targetUserId);
    console.log(`Edge Function (update-user-details-admin): Target User ID: ${targetUserId}, Target Profile: ${JSON.stringify(targetProfile)}`);
    console.log(`Edge Function (update-user-details-admin): Updates requested from client: ${JSON.stringify(updates)}`);

    if (!targetProfile || !targetProfile.role) {
      console.error(`Edge Function (update-user-details-admin): Target profile not found or role is missing for ${targetUserId}. Profile: ${JSON.stringify(targetProfile)}`);
      return new Response(JSON.stringify({ error: `Target user profile (ID: ${targetUserId}) not found or role is missing.` }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 404,
      });
    }

    // Ensure roles are consistently UPPERCASE for reliable comparisons
    const invokerRole = String(invokerProfile.role).toUpperCase() as UserRole;
    const targetRoleCurrent = String(targetProfile.role).toUpperCase() as UserRole;
    
    const finalUpdates: Partial<UpdateUserDetailsPayload['updates']> = { ...updates };
    let newRoleBeingSet: UserRole | undefined = undefined;

    if (finalUpdates.role) {
      const roleFromPayload = String(finalUpdates.role).toUpperCase();
      if (['USER', 'MODERATOR', 'ADMIN', 'SUPER_ADMIN'].includes(roleFromPayload)) {
        finalUpdates.role = roleFromPayload as UserRole;
        newRoleBeingSet = roleFromPayload as UserRole;
      } else {
        console.error(`Edge Function (update-user-details-admin): Invalid role value received: '${updates.role}', uppercased to: '${roleFromPayload}'`);
        return new Response(JSON.stringify({ error: `Invalid role value: ${updates.role}. Expected USER, MODERATOR, ADMIN, or SUPER_ADMIN.` }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400,
        });
      }
    }
    
    console.log(`Edge Function (update-user-details-admin): Invoker Role: ${invokerRole}, Current Target Role: ${targetRoleCurrent}, New Role to Set (if any): ${newRoleBeingSet}`);

    // Permission checks
    if (invokerRole === 'SUPER_ADMIN') {
      if (invokerUser.id === targetUserId && newRoleBeingSet && newRoleBeingSet !== 'SUPER_ADMIN') {
        console.warn(`Edge Function (update-user-details-admin): SUPER_ADMIN ${invokerUser.id} attempted to demote self.`);
        return new Response(JSON.stringify({ error: 'Super Admins cannot demote themselves.' }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 403,
        });
      }
      // SUPER_ADMIN can change anyone's role to anything (except demoting self)
      // SUPER_ADMIN can update any field for anyone (except demoting self from role)
    } else if (invokerRole === 'ADMIN') {
      if (invokerUser.id !== targetUserId && (targetRoleCurrent === 'ADMIN' || targetRoleCurrent === 'SUPER_ADMIN')) {
        console.warn(`Edge Function (update-user-details-admin): ADMIN ${invokerUser.id} attempted to modify another ADMIN/SUPER_ADMIN ${targetUserId}.`);
        return new Response(JSON.stringify({ error: 'Admins cannot modify other Admins or Super Admins.' }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 403,
        });
      }
      if (newRoleBeingSet === 'SUPER_ADMIN') {
        console.warn(`Edge Function (update-user-details-admin): ADMIN ${invokerUser.id} attempted to promote to SUPER_ADMIN.`);
        return new Response(JSON.stringify({ error: 'Admins cannot promote users to Super Admin.' }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 403,
        });
      }
      if (invokerUser.id === targetUserId && newRoleBeingSet && newRoleBeingSet !== 'ADMIN') {
         console.warn(`Edge Function (update-user-details-admin): ADMIN ${invokerUser.id} attempted to change own role to non-ADMIN.`);
         return new Response(JSON.stringify({ error: 'Admins cannot change their own role to a non-ADMIN role.' }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 403,
        });
      }
      // Admins can modify users with role USER or MODERATOR, or themselves (but not to SUPER_ADMIN or from ADMIN to something else)
      // Admins can change USER to MODERATOR or ADMIN (but not SUPER_ADMIN)
      // Admins can change MODERATOR to USER or ADMIN (but not SUPER_ADMIN)
      if (newRoleBeingSet && (targetRoleCurrent === 'ADMIN' || targetRoleCurrent === 'SUPER_ADMIN') && invokerUser.id !== targetUserId) {
         // This case is already handled above, but good to be explicit.
      }

    } else if (invokerRole === 'MODERATOR') {
      if (finalUpdates.role) { 
        console.warn(`Edge Function (update-user-details-admin): MODERATOR ${invokerUser.id} attempted to change role.`);
        return new Response(JSON.stringify({ error: 'Moderators cannot change user roles.' }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 403,
        });
      }
      if (targetRoleCurrent !== 'USER') {
        console.warn(`Edge Function (update-user-details-admin): MODERATOR ${invokerUser.id} attempted to modify non-USER.`);
        return new Response(JSON.stringify({ error: 'Moderators can only modify users with the "USER" role.' }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 403,
        });
      }
      const allowedUpdatesByModerator = ['status']; // Moderators can only change status of USERs
      for (const key in finalUpdates) {
        if (!allowedUpdatesByModerator.includes(key)) {
          console.warn(`Edge Function (update-user-details-admin): MODERATOR ${invokerUser.id} attempted to update restricted field '${key}'.`);
          return new Response(JSON.stringify({ error: `Moderators cannot update field: ${key}` }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 403,
          });
        }
      }
    } else { // Includes USER role or any other non-privileged role
      console.warn(`Edge Function (update-user-details-admin): Insufficient role ('${invokerRole}') for invoker ${invokerUser.id}.`);
      return new Response(JSON.stringify({ error: 'Permission denied. Insufficient role.' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 403,
      });
    }
    
    // If we've reached here, the invoker has permission to make the changes in finalUpdates.
    // Remove 'role' from finalUpdates if it was only used for permission checks and not actually set (e.g. undefined newRoleBeingSet)
    // However, if finalUpdates.role exists, it means a valid role change is intended and permitted.

    console.log(`Edge Function (update-user-details-admin): Permissions check passed. Updating profile ${targetUserId} with: ${JSON.stringify(finalUpdates)}`);
    
    const { data: updatedData, error: updateError } = await supabaseAdmin
      .from('profiles')
      .update(finalUpdates) // finalUpdates contains only permitted changes
      .eq('id', targetUserId)
      .select()
      .single();

    if (updateError) {
      console.error(`Edge Function (update-user-details-admin): Error updating profile ${targetUserId}:`, JSON.stringify(updateError));
      const errorDetails = (updateError as any).details || updateError.message || 'No details';
      const errorCode = (updateError as any).code || 'No code';
      console.error(`Edge Function (update-user-details-admin): PostgREST error code: ${errorCode}, details: ${errorDetails}`);

      if (errorCode === '23505' && errorDetails.includes('profiles_username_key')) {
        return new Response(JSON.stringify({ error: 'Username is already taken.', details: errorDetails }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 409, // Conflict
        });
      }
      if (errorCode === '23514') { // Check constraint violation (e.g. invalid enum value for role or status)
         return new Response(JSON.stringify({ error: 'Update violates a data validation rule (e.g., invalid role or status value).', details: errorDetails }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400, // Bad Request
        });
      }
      return new Response(JSON.stringify({ error: 'Failed to update profile.', details: errorDetails, code: errorCode }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500, // Internal Server Error for other update errors
      });
    }

    console.log(`Edge Function (update-user-details-admin): User ${targetUserId} details updated successfully. Data: ${JSON.stringify(updatedData)}`);
    return new Response(JSON.stringify({ message: 'User details updated successfully.', data: updatedData }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });

  } catch (error) { // Catch for the main try block
    console.error('Edge Function (update-user-details-admin): Unexpected error in main logic block:', error.message, JSON.stringify(error));
    return new Response(JSON.stringify({ error: 'Internal server error: ' + error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    });
  } // This closes the main try...catch block
}); // This closes the serve() function call's callback
