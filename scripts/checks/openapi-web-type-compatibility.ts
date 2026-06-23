import type {
  AuthLoginRequest,
  AuthTokenResponse,
  AuthUserResponse
} from '../../packages/shared/generated/openapi/auth-service'
import type {
  CreateToolRequest as OpenApiCreateToolRequest,
  RuntimeInfoResponse,
  TimerPreferenceConflictResponse,
  TimerPreferenceResponse,
  TimerPreferenceSaveRequest,
  ToolRecordResponse,
  UserPreferenceConflictResponse,
  UserPreferenceResponse,
  UserPreferenceSaveRequest,
  WorkbenchLayoutConflictResponse,
  WorkbenchLayoutResponse,
  WorkbenchLayoutSaveRequest
} from '../../packages/shared/generated/openapi/gateway'
import type {
  CreateToolRequest as WebCreateToolRequest,
  RuntimeInfo,
  TimerPreferenceConflictResponse as WebTimerPreferenceConflictResponse,
  TimerPreferenceRecord,
  TimerPreferenceSaveRequest as WebTimerPreferenceSaveRequest,
  ToolRecord,
  UserPreferenceConflictResponse as WebUserPreferenceConflictResponse,
  UserPreferenceRecord,
  UserPreferenceSaveRequest as WebUserPreferenceSaveRequest,
  WorkbenchLayoutConflictResponse as WebWorkbenchLayoutConflictResponse,
  WorkbenchLayoutRecord
} from '../../apps/web/app/types/hdx-api'
import type {
  BackendAuthTokenResponse,
  BackendAuthUser,
  WebAuthLoginRequest
} from '../../apps/web/app/types/hdx-auth'

type Assert<T extends true> = T
type IsAssignable<From, To> = [From] extends [To] ? true : false
type IsExact<Left, Right> =
  IsAssignable<Left, Right> extends true
    ? IsAssignable<Right, Left> extends true
      ? true
      : false
    : false

type OpenApiAuthTokenRequired = Required<AuthTokenResponse>
type OpenApiAuthUserRequired = Required<AuthUserResponse>
type OpenApiWorkbenchLayoutV1Response = Omit<WorkbenchLayoutResponse, 'schemaVersion'> & { schemaVersion: 1 }
type OpenApiWorkbenchLayoutConflictV1Response =
  Omit<WorkbenchLayoutConflictResponse, 'code' | 'resourceType' | 'serverLayout'>
  & {
    code: 'WORKBENCH_LAYOUT_CONFLICT'
    resourceType: 'workbenchLayout'
    serverLayout: OpenApiWorkbenchLayoutV1Response
  }
type OpenApiTimerPreferenceV1Response = Omit<TimerPreferenceResponse, 'schemaVersion'> & { schemaVersion: 1 }
type OpenApiTimerPreferenceConflictV1Response =
  Omit<TimerPreferenceConflictResponse, 'code' | 'resourceType' | 'serverPreference'>
  & {
    code: 'TIMER_PREFERENCE_CONFLICT'
    resourceType: 'timerPreferences'
    serverPreference: OpenApiTimerPreferenceV1Response
  }
type OpenApiUserPreferenceV1Response = Omit<UserPreferenceResponse, 'schemaVersion'> & { schemaVersion: 1 }
type OpenApiUserPreferenceConflictV1Response =
  Omit<UserPreferenceConflictResponse, 'code' | 'resourceType' | 'serverPreference'>
  & {
    code: 'USER_PREFERENCE_CONFLICT'
    resourceType: 'userPreferences'
    serverPreference: OpenApiUserPreferenceV1Response
  }

type _RuntimeInfoMatches = Assert<IsExact<RuntimeInfo, RuntimeInfoResponse>>
type _ToolRecordAcceptsOpenApi = Assert<IsAssignable<ToolRecordResponse, ToolRecord>>
type _ToolRecordCanRoundTripToOpenApi = Assert<IsAssignable<ToolRecord, ToolRecordResponse>>
type _CreateToolRequestMatches = Assert<IsAssignable<WebCreateToolRequest, OpenApiCreateToolRequest>>
type _WorkbenchLayoutAcceptsOpenApiV1 = Assert<IsAssignable<OpenApiWorkbenchLayoutV1Response, WorkbenchLayoutRecord>>
type _WorkbenchLayoutCanRoundTripToOpenApi = Assert<IsAssignable<WorkbenchLayoutRecord, WorkbenchLayoutSaveRequest>>
type _WorkbenchLayoutConflictAcceptsOpenApiV1 = Assert<IsAssignable<OpenApiWorkbenchLayoutConflictV1Response, WebWorkbenchLayoutConflictResponse>>
type _TimerPreferenceAcceptsOpenApiV1 = Assert<IsAssignable<OpenApiTimerPreferenceV1Response, TimerPreferenceRecord>>
type _TimerPreferenceCanRoundTripToOpenApi = Assert<IsAssignable<WebTimerPreferenceSaveRequest, TimerPreferenceSaveRequest>>
type _TimerPreferenceConflictAcceptsOpenApiV1 = Assert<IsAssignable<OpenApiTimerPreferenceConflictV1Response, WebTimerPreferenceConflictResponse>>
type _UserPreferenceAcceptsOpenApiV1 = Assert<IsAssignable<OpenApiUserPreferenceV1Response, UserPreferenceRecord>>
type _UserPreferenceCanRoundTripToOpenApi = Assert<IsAssignable<WebUserPreferenceSaveRequest, UserPreferenceSaveRequest>>
type _UserPreferenceConflictAcceptsOpenApiV1 = Assert<IsAssignable<OpenApiUserPreferenceConflictV1Response, WebUserPreferenceConflictResponse>>
type _LoginRequestMatches = Assert<IsAssignable<WebAuthLoginRequest, AuthLoginRequest>>
type _AuthUserAcceptsOpenApi = Assert<IsAssignable<OpenApiAuthUserRequired, BackendAuthUser>>
type _AuthTokenAcceptsOpenApi = Assert<IsAssignable<OpenApiAuthTokenRequired, BackendAuthTokenResponse>>
