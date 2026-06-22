import type {
  AuthLoginRequest,
  AuthTokenResponse,
  AuthUserResponse
} from '../../packages/shared/generated/openapi/auth-service'
import type {
  CreateToolRequest as OpenApiCreateToolRequest,
  RuntimeInfoResponse,
  ToolRecordResponse,
  WorkbenchLayoutResponse,
  WorkbenchLayoutSaveRequest
} from '../../packages/shared/generated/openapi/gateway'
import type {
  CreateToolRequest as WebCreateToolRequest,
  RuntimeInfo,
  ToolRecord,
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
type OpenApiWorkbenchLayoutV1Response = Omit<WorkbenchLayoutResponse, 'version'> & { version: 1 }

type _RuntimeInfoMatches = Assert<IsExact<RuntimeInfo, RuntimeInfoResponse>>
type _ToolRecordAcceptsOpenApi = Assert<IsAssignable<ToolRecordResponse, ToolRecord>>
type _ToolRecordCanRoundTripToOpenApi = Assert<IsAssignable<ToolRecord, ToolRecordResponse>>
type _CreateToolRequestMatches = Assert<IsAssignable<WebCreateToolRequest, OpenApiCreateToolRequest>>
type _WorkbenchLayoutAcceptsOpenApiV1 = Assert<IsAssignable<OpenApiWorkbenchLayoutV1Response, WorkbenchLayoutRecord>>
type _WorkbenchLayoutCanRoundTripToOpenApi = Assert<IsAssignable<WorkbenchLayoutRecord, WorkbenchLayoutSaveRequest>>
type _LoginRequestMatches = Assert<IsAssignable<WebAuthLoginRequest, AuthLoginRequest>>
type _AuthUserAcceptsOpenApi = Assert<IsAssignable<OpenApiAuthUserRequired, BackendAuthUser>>
type _AuthTokenAcceptsOpenApi = Assert<IsAssignable<OpenApiAuthTokenRequired, BackendAuthTokenResponse>>
